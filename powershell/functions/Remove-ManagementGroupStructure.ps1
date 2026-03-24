#Requires -PSEdition Core
#Requires -Modules Az.Accounts
#Requires -Modules Az.Resources
#Requires -Modules Az.ResourceGraph

<#
    .SYNOPSIS
    Resets the tenant management group configuration toward a root-only
    baseline.

    .DESCRIPTION
    This script performs three clean-up actions for Azure management groups:
    - Sets the default management group to the tenant root management group.
    - Moves subscriptions to the tenant root management group when needed.
    - Attempts to remove non-root management groups in repeated passes.

    The script uses Az Graph queries and management group operations at tenant
    scope. It writes progress and errors to the host output stream.

    .PARAMETER TenantRootManagementGroupId
    The tenant root management group ID used as the anchor for reset operations.

    .EXAMPLE
    $parameters = @{
        TenantRootManagementGroupId = 'contoso-root'
    }
    Remove-ManagementGroupStructure @parameters

    Sets the default management group to contoso-root, moves subscriptions under
    it, and removes non-root management groups where possible.

    .NOTES
    Run this script only when you intentionally want to flatten management group
    structure and re-parent subscriptions to tenant root.

    Requires permissions to read subscriptions, update management group
    settings, move subscriptions, and delete management groups.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Remove-ManagementGroupStructure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TenantRootManagementGroupId
    )

    #region - Reset the default management group to root
    $managementGroupsProviderUri = "https://management.azure.com/providers/Microsoft.Management/" +
    "managementGroups/$TenantRootManagementGroupId/" +
    "settings/default?api-version=2020-05-01"

    # Creating authentication header by getting the current token and decoding it to be used in the REST API call
    $currentToken = Get-AzAccessToken
    $token = $currentToken.Token | ConvertFrom-SecureString -AsPlainText
    $tokenType = $currentToken.Type
    $headers = @{
        Authorization  = "$tokenType $token"
        'Content-Type' = 'application/json'
    }

    # creating the request body
    $requestBody = '{
     "properties": {
          "defaultManagementGroup": "/providers/Microsoft.Management/managementGroups/' + $TenantRootManagementGroupId + '",
          "requireAuthorizationForGroupCreation": true
     }
}'

    $defaultMgResponse = Invoke-RestMethod -Method Get -Uri $managementGroupsProviderUri -Headers $headers

    if ($defaultMgResponse.properties.defaultManagementGroup -ne $TenantRootManagementGroupId) {
        Write-Host "Default management group is [$($defaultMgResponse.properties.defaultManagementGroup)] resetting to root management group"
        Invoke-RestMethod -Method 'PUT' -Uri $managementGroupsProviderUri -Headers $headers -Body $requestBody
    } else {
        Write-Host "Default management group is already set to tenant root management group"
    }
    #endregion

    #region - moving the existing subscriptions to the tenant management group root
    Write-Host "Moving all subscriptions to Tenant Root Management group"
    $listSubscriptionsQuery = 'resourcecontainers | where type == "microsoft.resources/subscriptions"'
    $graphResultSubscriptions = Search-AzGraph -Query $listSubscriptionsQuery -UseTenantScope
    Write-Host "Identified [$($graphResultSubscriptions.Count)] subscriptions in the tenant'"

    $graphResultSubscriptions.ForEach{
        $currentSub = $_

        if ($currentSub.properties.managementGroupAncestorsChain.Count -gt 1 -or $currentSub.properties.managementGroupAncestorsChain.name -ne $TenantRootManagementGroupId) {
            Write-Host " Moving subscription [$($currentSub.name)] under Tenant Root Management group"
            New-AzManagementGroupSubscription -GroupName $TenantRootManagementGroupId -SubscriptionId $currentSub.subscriptionId 3>&1 > $null
            Write-Host "  subscription moved"
        } else {
            Write-Host " Skipping, subscription [$($currentSub.name)] is already under the Tenant Root Management group"
        }
    }

    Write-Host "Moving of subscriptions has been completed`n"
    #endregion


    #region - removing all management groups
    $listManagementGroups = @'
resourcecontainers
| where type =~ 'microsoft.management/managementgroups'
| project name, properties.displayName
| order by ['name'] desc
'@

    $graphResultManagementGroups = Search-AzGraph -Query $listManagementGroups -UseTenantScope
    $allManagementGroups = $graphResultManagementGroups | Where-Object { $_.name -ne $TenantRootManagementGroupId }

    # delete all management groups until no remain
    while ($allManagementGroups.Count -gt 1) {

        $allManagementGroups.ForEach{
            $currentMg = $_
            try {
                Write-Host "Removing management group [$($currentMg.name)]"
                Remove-AzManagementGroup -GroupName $currentMg.name 3>&1 > $null
                Write-Host " group removed"
            } catch {
                # swallow the exception
                Write-Host "Failed removing [$($currentMg.name)]."
                Write-Warning -Message "$($_.Exception.Message)"
            }
        }

        # get any remaining management groups that could not be deleted due to inheritance
        $graphResultManagementGroups = Search-AzGraph -Query $listManagementGroups -UseTenantScope
        $allManagementGroups = $graphResultManagementGroups | Where-Object { $_.name -ne $TenantRootManagementGroupId }
    }
    #endregion

    Write-Host "All done!!"
}
