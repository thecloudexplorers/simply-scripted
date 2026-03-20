#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Detects and removes rogue role assignments at a specified Azure scope.

    .DESCRIPTION
    This function retrieves all direct (non-inherited) role assignments and
    eligible PIM schedule instances at the specified scope, removing any that
    are not declared in the provided allowed lists. The following categories
    of rogue assignments are handled:

    - Direct user assignments: Always considered rogue; removed with a warning.
    - Undeclared security group assignments: Any group not present in
      AllowedGroupNames is removed with a warning.
    - Undeclared service principal assignments: Any service principal / app
      registration not present in AllowedServicePrincipalNames is removed with
      a warning.
    - Eligible (PIM, not yet activated) assignments: Evaluated with the same
      rules as direct assignments. Removed via
      New-AzRoleEligibilityScheduleRequest -RequestType AdminRemove.

    Assignments with an unresolvable object type (Unknown) are skipped and a
    warning is emitted so they can be investigated manually.

    Supports -WhatIf and -Confirm via ShouldProcess. Use -WhatIf to preview
    which assignments would be removed without making any changes.

    .PARAMETER RoleAssignmentScope
    The full Azure resource ID scope at which rogue role assignments are
    evaluated and removed. Only direct assignments (i.e. those whose Scope
    property exactly matches this value) are checked; inherited assignments
    from parent scopes are not removed.

    .PARAMETER AllowedGroupNames
    Display names of Entra ID security groups that are permitted to hold role
    assignments at the specified scope. Pass an empty array when no groups are
    declared for the scope.

    .PARAMETER AllowedServicePrincipalNames
    Display names of Entra ID service principals (App Registrations) that are
    permitted to hold role assignments at the specified scope. Pass an empty
    array when no service principals are declared for the scope.

    .EXAMPLE
    $params = @{
        RoleAssignmentScope          = "/providers/Microsoft.Management/managementGroups/mg10001"
        AllowedGroupNames            = @("CloudPlatformEngineer", "CloudSecurityEngineer")
        AllowedServicePrincipalNames = @("my-app-registration")
    }
    Remove-AzRogueRoleAssignments @params

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Remove-AzRogueRoleAssignments {
    [CmdLetBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $RoleAssignmentScope,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.String[]] $AllowedGroupNames,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.String[]] $AllowedServicePrincipalNames
    )

    Write-Debug -Message "   Retrieving all direct role assignments for scope [$RoleAssignmentScope]"
    # -AtScope limits results to the exact scope; 3>$null suppresses non-terminating warnings emitted by the cmdlet (e.g. unresolvable principals). The Where-Object
    # filter additionally excludes any inherited assignments that slipped through.
    $directAssignments = Get-AzRoleAssignment -Scope $RoleAssignmentScope -AtScope 3> $null | Where-Object { $_.Scope -eq $RoleAssignmentScope }

    Write-Debug -Message "   Retrieving all eligible role assignments for scope [$RoleAssignmentScope]"
    # Get-AzRoleEligibilityScheduleInstance returns PIM eligible assignments roles a principal is allowed to activate but has not yet activated.
    # These are invisible to Get-AzRoleAssignment and must be queried separately.
    $eligibleScheduled = Get-AzRoleEligibilityScheduleInstance -Scope $RoleAssignmentScope 3> $null | Where-Object { $_.Scope -eq $RoleAssignmentScope }

    if ($null -eq $directAssignments -or @($directAssignments).Count -eq 0) {
        Write-Host "   No direct role assignments found at scope [$RoleAssignmentScope]"
    }

    # Tracks whether at least one rogue assignment was found across both loops,
    # used to emit the final success message when everything is clean.
    $rogueFound = $false

    foreach ($assignment in $directAssignments) {
        # Some role assignments may have unresolvable principals (e.g. deleted objects); attempt to resolve the display name for better logging,
        # but fall back gracefully when resolution fails.
        $displayName = $assignment.DisplayName
        if ([string]::IsNullOrEmpty($displayName)) { $displayName = 'Unknown' }

        Write-Debug -Message "Evaluating role assignment for principal [$displayName] with ObjectId: [$($assignment.ObjectId)] and Role [$($assignment.RoleDefinitionName)]"
        $principalInfo = "Principal [$displayName] with ObjectId: [$($assignment.ObjectId)] and Role [$($assignment.RoleDefinitionName)]"

        # Branch on the resolved principal type. Users are never permitted to hold direct role assignments — policy requires group or service principal only.
        # Unknown principals are orphaned objects whose Entra ID record was deleted; they should be removed as they cannot be validated against the allow lists.
        switch ($assignment.ObjectType) {
            'User' {
                $rogueFound = $true

                Write-Warning "ROGUE DIRECT USER DETECTED:"
                Write-Warning "$principalInfo. Direct user assignments are not permitted. Removing..."
                if ($PSCmdlet.ShouldProcess($principalInfo, 'Remove direct user role assignment')) {
                    Remove-AzRoleAssignment -InputObject $assignment 1> $null
                    Write-Host "   REMOVED: Direct user assignment for $principalInfo"
                }
            }

            'Unknown' {
                $rogueFound = $true

                Write-Warning "UNKNOWN PRINCIPAL DETECTED:"
                Write-Warning "$principalInfo. Principal no longer exists in the current tenant. Removing..."
                if ($PSCmdlet.ShouldProcess($principalInfo, 'Remove unknown principal role assignment')) {
                    Remove-AzRoleAssignment -InputObject $assignment 1> $null
                    Write-Host "   REMOVED: Principal assignment for $principalInfo"
                }
            }

            'Group' {
                # Only groups explicitly listed in AllowedGroupNames are permitted. Any group not in the list is considered undeclared and removed.
                if ($assignment.DisplayName -notin $AllowedGroupNames) {
                    $rogueFound = $true

                    Write-Warning "ROGUE GROUP DETECTED:"
                    Write-Warning "$principalInfo is not declared in the configuration. Removing..."
                    if ($PSCmdlet.ShouldProcess($principalInfo, 'Remove rogue group role assignment')) {
                        Remove-AzRoleAssignment -InputObject $assignment 1> $null
                        Write-Host "   REMOVED: Group assignment for $principalInfo"
                    }
                }
            }

            'ServicePrincipal' {
                # Only service principals explicitly listed in AllowedServicePrincipalNames are permitted. This covers app registrations and managed identities.
                if ($assignment.DisplayName -notin $AllowedServicePrincipalNames) {
                    $rogueFound = $true

                    Write-Warning "ROGUE SERVICE PRINCIPAL DETECTED:"
                    Write-Warning "$principalInfo is not declared in the configuration. Removing..."
                    if ($PSCmdlet.ShouldProcess($principalInfo, 'Remove rogue service principal role assignment')) {
                        Remove-AzRoleAssignment -InputObject $assignment 1> $null
                        Write-Host "   REMOVED: Service principal assignment for $principalInfo"
                    }
                }
            }

            default {
                # Emit a warning for any unrecognized type so it can be investigated manually; do not attempt removal to avoid unintended data loss.
                Write-Warning "Unable to resolve object type [$($assignment.ObjectType)] for $principalInfo at scope [$RoleAssignmentScope]. Manual investigation required."
            }
        }
    }

    Write-Debug -Message "   Processing eligible role assignment schedule instances for scope [$RoleAssignmentScope]"

    if ($null -eq $eligibleScheduled -or @($eligibleScheduled).Count -eq 0) {
        Write-Host "   SUCCESS: No rogue eligible role assignment schedule instances found."
    }

    foreach ($eligibleAssignment in $eligibleScheduled) {
        # Eligible schedule instances expose PrincipalId/PrincipalType rather than DisplayName, so resolve the human-readable name via the Graph cmdlets.
        $displayName = switch ($eligibleAssignment.PrincipalType) {
            'User' { (Get-AzADUser -ObjectId $eligibleAssignment.PrincipalId -ErrorAction SilentlyContinue).DisplayName }
            'Group' { (Get-AzADGroup -ObjectId $eligibleAssignment.PrincipalId -ErrorAction SilentlyContinue).DisplayName }
            'ServicePrincipal' { (Get-AzADServicePrincipal -ObjectId $eligibleAssignment.PrincipalId -ErrorAction SilentlyContinue).DisplayName }
            default { $null }
        }
        if ([string]::IsNullOrEmpty($displayName)) { $displayName = 'Unknown' }

        # RoleDefinitionId is a full ARM resource ID; extract the trailing GUID and resolve it to a friendly name. Fall back to the raw GUID if not found.
        $roleDefGuid = ($eligibleAssignment.RoleDefinitionId -split '/')[-1]
        $roleDefinitionName = (Get-AzRoleDefinition -Id $roleDefGuid -ErrorAction SilentlyContinue).Name
        if ([string]::IsNullOrEmpty($roleDefinitionName)) { $roleDefinitionName = $roleDefGuid }

        $eligiblePrincipalInfo = "Principal [$displayName] with ObjectId: [$($eligibleAssignment.PrincipalId)] and Role [$roleDefinitionName]"
        Write-Debug -Message "Evaluating eligible role assignment for $eligiblePrincipalInfo"

        # Build the splatted parameter set for New-AzRoleEligibilityScheduleRequest. AdminRemove is the correct RequestType for removing an eligible assignment
        # without requiring the principal to first deactivate it. A new GUID is required for each request as the Name must be unique.
        $removeEligibleParams = @{
            Name             = (New-Guid).Guid
            Scope            = $RoleAssignmentScope
            PrincipalId      = $eligibleAssignment.PrincipalId
            RoleDefinitionId = $eligibleAssignment.RoleDefinitionId
            RequestType      = 'AdminRemove'
        }

        # Apply the same allow-list rules as for direct assignments.
        switch ($eligibleAssignment.PrincipalType) {
            'User' {
                $rogueFound = $true

                Write-Warning "ROGUE ELIGIBLE USER DETECTED:"
                Write-Warning "$eligiblePrincipalInfo. Direct user eligible assignments are not permitted. Removing..."
                if ($PSCmdlet.ShouldProcess($eligiblePrincipalInfo, 'Remove eligible user PIM assignment')) {
                    New-AzRoleEligibilityScheduleRequest @removeEligibleParams 1> $null
                    Write-Host "   REMOVED: Eligible user assignment for $eligiblePrincipalInfo"
                }
            }

            'Unknown' {
                $rogueFound = $true

                Write-Warning "UNKNOWN ELIGIBLE PRINCIPAL DETECTED:"
                Write-Warning "$eligiblePrincipalInfo. Principal no longer exists in the current tenant. Removing..."
                if ($PSCmdlet.ShouldProcess($eligiblePrincipalInfo, 'Remove unknown eligible principal PIM assignment')) {
                    New-AzRoleEligibilityScheduleRequest @removeEligibleParams 1> $null
                    Write-Host "   REMOVED: Eligible principal assignment for $eligiblePrincipalInfo"
                }
            }

            'Group' {
                if ($displayName -notin $AllowedGroupNames) {
                    $rogueFound = $true

                    Write-Warning "ROGUE ELIGIBLE GROUP DETECTED:"
                    Write-Warning "$eligiblePrincipalInfo is not declared in the configuration. Removing..."
                    if ($PSCmdlet.ShouldProcess($eligiblePrincipalInfo, 'Remove rogue eligible group PIM assignment')) {
                        New-AzRoleEligibilityScheduleRequest @removeEligibleParams 1> $null
                        Write-Host "   REMOVED: Eligible group assignment for $eligiblePrincipalInfo"
                    }
                }
            }

            'ServicePrincipal' {
                if ($displayName -notin $AllowedServicePrincipalNames) {
                    $rogueFound = $true

                    Write-Warning "ROGUE ELIGIBLE SERVICE PRINCIPAL DETECTED:"
                    Write-Warning "$eligiblePrincipalInfo is not declared in the configuration. Removing..."
                    if ($PSCmdlet.ShouldProcess($eligiblePrincipalInfo, 'Remove rogue eligible service principal PIM assignment')) {
                        New-AzRoleEligibilityScheduleRequest @removeEligibleParams 1> $null
                        Write-Host "   REMOVED: Eligible service principal assignment for $eligiblePrincipalInfo"
                    }
                }
            }

            default {
                Write-Warning ("Unable to resolve object type [$($eligibleAssignment.PrincipalType)] for " +
                    "$eligiblePrincipalInfo at scope [$RoleAssignmentScope]. Manual investigation required.")
            }
        }
    }

    if (-not $rogueFound) {
        Write-Host "   SUCCESS: No rogue role assignments detected"
    }
}
