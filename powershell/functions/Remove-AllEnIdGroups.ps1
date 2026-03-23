#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Removes Entra ID groups from a tenant, excluding specified group names.

    .DESCRIPTION
    Remove-AzADCustomGroup retrieves groups from the provided tenant context,
    excludes groups listed in ExcludeFilter, and removes the remaining groups.

    The function supports ShouldProcess, so -WhatIf and -Confirm can be used
    for safe execution.

    .PARAMETER Tenant
    Tenant context used for group cleanup.

    .PARAMETER ExcludeFilter
    Array of group display names that must be excluded from removal.

    .EXAMPLE
    $parameters = @{
        Tenant        = (Get-AzContext).Tenant
        ExcludeFilter = @("Canary Platform", "Test Group")
        WhatIf        = $true
    }
    Remove-AzADCustomGroup @parameters

    Shows which groups would be removed without making changes.

    .NOTES
    Requires an authenticated Az context with permissions to read and remove
    Entra ID groups.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>
function Remove-AzADCustomGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant]$Tenant,

        [Parameter(Mandatory)]
        [System.String[]]$ExcludeFilter
    )

    # Get list of all security groups and exclude one in ExcludeFilter
    $groupsToRemove = Get-AzADGroup | Where-Object { $_.DisplayName -notin $ExcludeFilter }

    # Iterate through the filtered list of security groups and remove each group
    foreach ($group in $groupsToRemove) {
        Write-Host "Removing group: $($group.DisplayName)" -ForegroundColor Cyan
        try {
            if ($PSCmdlet.ShouldProcess( $group, "Remove-AzADGroup")) {
                $group | Remove-AzADGroup
            } else {
                $group | Remove-AzADGroup -WhatIf
            }
        } catch {
            Write-Host "An error occurred while removing Azure AD groups: [$($_.Exception.Message)]" -ForegroundColor Red
        }
    }
    Write-Host "Removed $($groupsToRemove.Count) groups." -ForegroundColor Green
}
