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

    .PARAMETER ExcludeFilter
    Optional array of application object IDs to exclude from removal.

    .EXAMPLE
    $parameters = @{
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
        [ValidateNotNullOrEmpty()]
        [String[]] $ExcludeFilter
    )

    Write-Host "Start cleaning App registrations"

    # Prepare OData filter expression to pass it to Get-MgApplication -Filter parameter to make filter in one call
    # https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http
    $filter = "NOT(id in ($($ExcludeFilter | Join-String -SingleQuote -Separator ',')))"

    # Use Advanced query parameters to return filtered applications
    # https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
    $appsToRemoveFiltered = Get-MgApplication -Filter $filter -ConsistencyLevel eventual -CountVariable 1

    # Iterate through the filtered list of AAD Apps registered and remove each App
    foreach ($app in $appsToRemoveFiltered) {
        Write-Host "Removing AppRegistration: $($app.DisplayName)" -ForegroundColor Cyan
        try {
            # Support -WhatIf and -Confirm parameters for safe execution
            if ($PSCmdlet.ShouldProcess( $app, "Remove-AzADAppRegistration")) {
                $app | Remove-AzADApplication
            }
        } catch {
            Write-Host "An error occurred while removing Azure AD App: [$($_.Exception.Message)]" -ForegroundColor Red -ErrorAction Continue
        }
    }
    Write-Host "Removed $($appsToRemoveFiltered.Count) AAD Apps registered." -ForegroundColor Green
}
