#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Removes Entra ID groups from the tenant in the current context, excluding specified group names.

    .DESCRIPTION
    Remove-AllEnIdGroups retrieves groups from the current tenant context,
    excludes groups listed in ExcludeFilter, and removes the remaining groups.

    The function supports ShouldProcess, so -WhatIf and -Confirm can be used
    for safe execution.

    .PARAMETER ExcludeFilter
    Array of group display names that must be excluded from removal.

    .EXAMPLE
    $parameters = @{
        ExcludeFilter = @("Canary Platform", "Test Group")
        WhatIf        = $true
    }
    Remove-AllEnIdGroups @parameters

    Shows which groups would be removed without making changes.

    .NOTES
    Requires an authenticated Az context with permissions to read and remove
    Entra ID groups.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>
function Remove-AllEnIdGroups {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateNotNullOrEmpty()]
        [System.String[]] $ExcludeFilter
    )

    Write-Host "Start cleaning App registrations"
    # Get list of all security groups and exclude one in ExcludeFilter
    [System.Object[]] $groupsToRemove = Get-AzADGroup | Where-Object { $_.DisplayName -notin $ExcludeFilter }

    # Iterate through the filtered list of security groups and remove each group
    foreach ($group in $groupsToRemove) {
        Write-Host "Removing group [$($group.DisplayName)]" -ForegroundColor Cyan
        try {
            # Support -WhatIf and -Confirm parameters for safe execution
            if ($PSCmdlet.ShouldProcess($group.DisplayName, "Remove-AllEnIdGroups")) {
                $group | Remove-AzADGroup
            }
        } catch {
            Write-Host "An error occurred while removing Azure AD groups: [$($_.Exception.Message)]" -ForegroundColor Red -ErrorAction Continue
        }
    }
    Write-Host "Removed [$($groupsToRemove.Count)] groups." -ForegroundColor Green
}
