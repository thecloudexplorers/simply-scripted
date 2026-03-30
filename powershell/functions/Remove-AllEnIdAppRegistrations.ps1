#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Removes Entra ID app registrations in a tenant, excluding specified app IDs.

    .DESCRIPTION
    Remove-AllEnIdAppRegistrations queries applications in Microsoft Graph for the
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
    Remove-AllEnIdAppRegistrations @parameters

    Shows which app registrations would be removed without making changes.

    .NOTES
    Requires an authenticated Microsoft Graph context for Get-MgApplication and
    the required permissions to remove applications.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>
function Remove-AllEnIdAppRegistrations {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateNotNullOrEmpty()]
        [System.String[]] $ExcludeFilter
    )

    Write-Host "Start cleaning App registrations" -ForegroundColor Cyan

    $currentToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
    Connect-MgGraph -AccessToken $currentToken.Token -NoWelcome

    # Retrieve all app registrations and exclude those matching ExcludeFilter display names
    # https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
    $appsToRemoveFiltered = Get-MgApplication -All | Where-Object { $_.DisplayName -notin $ExcludeFilter }

    # Iterate through the filtered list of Entra ID Apps and remove each App
    foreach ($app in $appsToRemoveFiltered) {
        Write-Host "Removing AppRegistration [$($app.DisplayName)]" -ForegroundColor Cyan
        try {
            # Support -WhatIf and -Confirm parameters for safe execution
            if ($PSCmdlet.ShouldProcess($app.DisplayName, "Remove-AllEnIdAppRegistrations")) {
                $app | Remove-AzADApplication
            }
        } catch {
            Write-Host "An error occurred while removing Entra ID App [$($app.DisplayName)]: [$($_.Exception.Message)]" -ForegroundColor Red -ErrorAction Continue
        }
    }
    Write-Host "Removed $($appsToRemoveFiltered.Count) Entra ID Apps" -ForegroundColor Green
}
