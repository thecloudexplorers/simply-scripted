#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Removes Entra ID app registrations in a tenant, excluding specified app IDs.

    .DESCRIPTION
    Remove-AzADAppRegistration queries applications in Microsoft Graph for the
    provided tenant and removes app registrations that are not part of the
    ExcludeFilter list.

    The function supports ShouldProcess, so you can run with -WhatIf and
    -Confirm for safe execution.

    .PARAMETER Tenant
    Tenant context to target for app registration cleanup.

    .PARAMETER ExcludeFilter
    Optional array of application object IDs to exclude from removal.

    .EXAMPLE
    $parameters = @{
        Tenant        = (Get-AzContext).Tenant
        ExcludeFilter = @("AppId1", "AppId2")
        WhatIf        = $true
    }
    Remove-AzADAppRegistration @parameters

    Shows which app registrations would be removed without making changes.

    .NOTES
    Requires an authenticated Microsoft Graph context for Get-MgApplication and
    the required permissions to remove applications.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>
function Remove-AzADAppRegistration {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant]$Tenant,

        [String[]]$ExcludeFilter
    )

    Write-Host "Start cleaning App registration in Tenant: [$($Tenant.Id)]"

    # prepare OData filter expression to pass it to Get-MgApplication -Filter parameter to make filter in one call
    # https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http
    $filter = "NOT(id in ($($ExcludeFilter | Join-String -SingleQuote -Separator ',')))"

    # use Advanced query parameters to return filtered applications
    # https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
    $appsToRemoveFiltered = Get-MgApplication -Filter $filter -ConsistencyLevel eventual -CountVariable 1

    # iterate through the filtered list of AAD Apps registered and remove each App
    foreach ($app in $appsToRemoveFiltered) {
        Write-Host "Removing AppRegistration: $($app.DisplayName)"
        try {
            if ($PSCmdlet.ShouldProcess( $app, "Remove-AzADAppRegistration")) {
                $app | Remove-AzADApplication
            } else {
                $app | Remove-AzADApplication -WhatIf
            }
        } catch {
            Write-Warning -Message "An error occurred while removing Azure AD App: [$($_.Exception.Message)]"
        }
    }
    Write-Host "Removed $($appsToRemoveFiltered.Count) AAD Apps registered."
}
