#Requires -Modules Az.ResourceGraph, Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Exports Azure role assignments with resolved principal names to CSV.

.DESCRIPTION
    This function queries Azure Resource Graph to retrieve all role assignments
    across your Azure environment and enriches the data by resolving principal
    IDs to their display names using Azure AD cmdlets.

    The function leverages Azure Resource Graph's authorizationresources table
    to efficiently query role assignments at scale, avoiding the limitations of
    traditional Azure PowerShell cmdlets. It then performs lookups to translate
    Object IDs into human-readable principal names (users, groups, service
    principals, and managed identities).

    The output includes:
    - Role assignment details (scope, role definition, assignment type)
    - Resolved principal information (name, type)
    - Assignment metadata (created date, updated date, conditions)

    Results are exported to a CSV file for easy analysis and reporting.

.PARAMETER OutputPath
    The file path where the CSV output will be saved.
    Defaults to the current directory with a timestamp in the filename:
    "AzureRoleAssignments_YYYYMMDD_HHMMSS.csv"

.PARAMETER SubscriptionId
    Optional subscription ID to limit the scope of the query.
    When specified, only role assignments within that subscription are returned.
    If omitted, the function queries all subscriptions accessible to the
    current Azure context.

.EXAMPLE
    Export-AzRoleAssignmentsWithPrincipalNames

    Exports all role assignments from all accessible subscriptions to a
    timestamped CSV file in the current directory.

.EXAMPLE
    Export-AzRoleAssignmentsWithPrincipalNames -OutputPath "C:\Reports\roles.csv"

    Exports all role assignments to the specified file path.

.EXAMPLE
    Export-AzRoleAssignmentsWithPrincipalNames -SubscriptionId "12345678-90ab-cdef-1234-567890abcdef"

    Exports role assignments for a specific subscription only.

.EXAMPLE
    $params = @{
        SubscriptionId = "12345678-90ab-cdef-1234-567890abcdef"
        OutputPath     = "C:\Reports\prod-roles.csv"
    }
    Export-AzRoleAssignmentsWithPrincipalNames @params

    Exports role assignments for a specific subscription to a custom location.

.INPUTS
    None. You cannot pipe objects to this function.

.OUTPUTS
    System.IO.FileInfo
    Returns a FileInfo object representing the generated CSV file.

.NOTES
    Version     : 0.0.1
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    This function extends the KQL query pattern shared by Jason Fritts in his
    blog post "Export all Azure role assignments using Azure Resource Graph".
    The enhancement adds principal name resolution to make the exported data
    more human-readable and actionable for access reviews and compliance audits.

    Prerequisites:
    - Az.Accounts module (for Azure authentication)
    - Az.ResourceGraph module (for querying role assignments)
    - Az.Resources module (for resolving principal names)
    - Appropriate Azure RBAC permissions (Reader or higher)
    - Microsoft Graph permissions for reading directory objects

.LINK
    https://www.jasonfritts.me/2024/08/22/export-all-azure-role-assignments-using-azure-resource-graph/
    https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources?wt.mc_id=DT-MVP-5005327

.LINK
    https://github.com/thecloudexplorers/simply-scripted
#>

function Export-AzRoleAssignmentsWithPrincipalNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $OutputPath,

        [Parameter(Mandatory = $false)]
        [System.String] $SubscriptionId
    )

    # Query to export all Azure role assignments using Azure Resource Graph
    # Courtesy of Jason Fritts
    # NOTE: projecting the id column is required to use  -SkipToken for pagination.
    $query = @"
authorizationresources
| where type == "microsoft.authorization/roleassignments"
| extend scope = tostring(properties['scope'])
| extend principalType = tostring(properties['principalType'])
| extend principalId = tostring(properties['principalId'])
| extend roleDefinitionId = tolower(tostring(properties['roleDefinitionId']))
| mv-expand createdOn = parse_json(properties).createdOn
| mv-expand updatedOn = parse_json(properties).updatedOn
| join kind=inner (
authorizationresources
| where type =~ 'microsoft.authorization/roledefinitions'
| extend id = tolower(id)
) on `$left.roleDefinitionId == `$right.id
| mv-expand roleName = parse_json(properties1).roleName
| project id, createdOn, updatedOn, principalId, principalType, scope, roleName, roleDefinitionId
"@

    # Execute the query, with optional subscription scoping
    try {
        $batchSize = 1000
        $skipResult = 0
        $azGraphResults = [System.Collections.Generic.List[object]]::new()

        if ($SubscriptionId) {
            Write-Information -MessageData  "Querying Azure Resource Graph for Role Assignments at Subscription scope [$SubscriptionId]"
        } else {
            Write-Information -MessageData  "Querying Azure Resource Graph for Role Assignments at Tenant scope"
        }

        # Handle pagination following Microsoft's recommended pattern
        while ($true) {
            if ($skipResult -gt 0) {
                Write-Information -MessageData  "Fetching next $batchSize results..."
                if ($SubscriptionId) {
                    # A subscription ID is provided, scope the query to that subscription
                    $searchAzGraphParams = @{
                        Query        = $query
                        Subscription = $SubscriptionId
                        First        = $batchSize
                        SkipToken    = $graphResult.SkipToken
                    }
                    $graphResult = Search-AzGraph @searchAzGraphParams
                } else {
                    # Use tenant scope
                    $searchAzGraphParams = @{
                        Query     = $query
                        First     = $batchSize
                        SkipToken = $graphResult.SkipToken
                    }
                    $graphResult = Search-AzGraph @searchAzGraphParams -UseTenantScope
                }
            } else {
                # First query
                if ($SubscriptionId) {
                    $searchAzGraphParams = @{
                        Query        = $query
                        Subscription = $SubscriptionId
                        First        = $batchSize
                    }
                    $graphResult = Search-AzGraph @searchAzGraphParams
                } else {
                    $graphResult = Search-AzGraph -Query $query -UseTenantScope -First $batchSize
                }
            }

            # Add results from this batch using AddRange to properly handle the array
            $azGraphResults.AddRange($graphResult.data)

            # Break if we received fewer results than batch size (last page)
            if ($graphResult.data.Count -lt $batchSize) {
                break
            }

            $skipResult += $skipResult + $batchSize
        }

        Write-Information -MessageData  "Total role assignments found [$($azGraphResults.Count)]"
    } catch {
        Write-Error "Failed to query Azure Resource Graph: $_" -ErrorAction Stop
    }

    # Resolve principal names using Az cmdlets
    Write-Information -MessageData  "Resolving principal id's to display names"

    $resolvedResults = @()
    $progressCount = 0
    # keep track of principals which could not be resolved to a display name
    $unresolvedResultsCount = 0

    foreach ($currentAssignment in $azGraphResults) {
        # Update progress count
        $progressCount++
        $writeProgressParams = @{
            Activity        = "Resolving principal id's to display names"
            Status          = "Processing $progressCount of $($azGraphResults.Count)"
            PercentComplete = (($progressCount / $azGraphResults.Count) * 100)
        }
        Write-Progress @writeProgressParams

        $principalName = $null
        try {
            $principal = $null

            # Try to resolve based on principal type
            switch ($currentAssignment.principalType) {
                'ServicePrincipal' {
                    $principal = Get-AzADServicePrincipal -ObjectId $currentAssignment.principalId -ErrorAction Stop
                }
                'User' {
                    $principal = Get-AzADUser -ObjectId $currentAssignment.principalId -ErrorAction Stop
                }
                'Group' {
                    $principal = Get-AzADGroup -ObjectId $currentAssignment.principalId -ErrorAction Stop
                }
                default {
                    Write-Warning -Message "Unsupported principal type [$($currentAssignment.principalType)] for principal ID [$($currentAssignment.principalId)]"
                }
            }

            if ($null -ne $principal) {
                # Get display name or UPN
                $principalName = $principal.DisplayName
                if ([string]::IsNullOrEmpty($principalName)) {
                    $principalName = $principal.UserPrincipalName
                }
            }
        } catch {
            if ($_.FullyQualifiedErrorId.StartsWith('Request_ResourceNotFound')) {
                Write-Warning -Message "Could not resolve principal ID [$($currentAssignment.principalId)]"
                Write-Warning -Message "$($_.Exception.Message)"
                $principalName = "Not Found"
                $unresolvedResultsCount++
            } else {
                Write-Error -Message "Unexpected error resolving principal ID [$($currentAssignment.principalId)]: $_" -ErrorAction Stop
            }
        }


        # If still not resolved, use the principal ID
        if ([string]::IsNullOrEmpty($principalName)) {
            $principalName = $currentAssignment.principalId
        }

        $resolvedResults += [PSCustomObject]@{
            CreatedOn        = $currentAssignment.createdOn
            UpdatedOn        = $currentAssignment.updatedOn
            PrincipalName    = $principalName
            PrincipalId      = $currentAssignment.principalId
            PrincipalType    = $currentAssignment.principalType
            Scope            = $currentAssignment.scope
            RoleName         = $currentAssignment.roleName
            RoleDefinitionId = $currentAssignment.roleDefinitionId
        }
    }

    Write-Progress -Activity "Resolving principal names" -Completed

    # Export to CSV
    Write-Information -MessageData  "Exporting data as csv at [$OutputPath]"

    try {
        $resolvedResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Information -MessageData  "Successfully exported [$($resolvedResults.Count)] role assignments to [$OutputPath]"
    } catch {
        Write-Error -Message "Failed to export to CSV [$_]"
    }

    # Display summary
    Write-Information -MessageData  "`nSummary:"
    Write-Information -MessageData  "  Total role assignments [$($resolvedResults.Count)]"
    Write-Information -MessageData  "  Unique principals [$((($resolvedResults | Select-Object -Unique PrincipalId).Count))]"
    Write-Information -MessageData  "  Unique roles [$((($resolvedResults | Select-Object -Unique RoleName).Count))]"

    Write-Information -MessageData  "`nTop 5 roles:"
    $resolvedResults | Group-Object RoleName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Information -MessageData  "  $($_.Name): $($_.Count)"
    }

    Write-Information -MessageData  "`nUnresolved principal assignments [$unresolvedResultsCount]"
}
