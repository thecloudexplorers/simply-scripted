#requires -Modules Az.Resources
<#
    .SYNOPSIS
    Creates an Azure Active Directory App Registration (application)

    .DESCRIPTION
    This function creates an Creates an Azure Active Directory App Registration and a corresponding Enterprise application
    In addition the description field is also set using the supplied input

    .PARAMETER AzAdApps
    A collection Azure AD Application objects to create

    .EXAMPLE
    Object example:
    "azAdApplications": [
        {
        "name": "demojev-tce-d-sc-arm",
        "description": "Example description"
        },
        {
        "name": "demojev-tce-t-sc-arm",
        "description": ""Example description"
        },
        {
        "name": "demojev-tce-a-sc-arm",
        "description": ""Example description"
        },
    ]

    $azAdAppsArgs = @{
        AzAdApps = azAdApplictionsColl
    }
    New-AzAdApps @azAdAppsArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azadapplication?view=azps-9.3.0
#>

function New-AzAdApps {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]] $AzAdApps
    )

    $AzAdApps.ForEach{
        $azAdApp = $_

        # ensuring the description is not $null as an $null value is not accepted during creation
        if ([string]::IsNullOrEmpty($azAdApp.description)) {
            $azAdApp.description = " "
        }

        $appExists = Get-AzADApplication -Filter "DisplayName eq '$($azAdApp.name)'"

        if ($null -eq $appExists) {
            Write-Information -MessageData " Creating AzAd Application [$($azAdApp.name)]"
            $newApp = New-AzADApplication -DisplayName $azAdApp.name -Note $azAdApp.description

            # create a corresponding enterprise application for the app registration in question
            Write-Information -MessageData "  Creating AzAd Service Principal for the concerning AzAd Application"
            New-AzADServicePrincipal -ApplicationId $newApp.AppId -Note $azAdApp.description 1>$null
            Write-Information -MessageData "  AzAd Service Principal has been created"
            Write-Information -MessageData " Application has been created"

        } else {
            Write-Information -MessageData " AzAd Application [$($azAdApp.name)] is already present, applying drift control"
            [System.Boolean]$driftDetected = $false

            # ensuring the correct description is set in the note field of the application
            if ($appExists.Note -ne $azAdApp.description) {
                $driftDetected = $true
                $appExists | Update-AzAdApplication -Note $azAdApp.description
                Write-Information -MessageData "  UPDATED: Application note value has been corrected"
            }

            # ensuring enterprise application is present
            $servicePrincipalExists = Get-AzADServicePrincipal -ApplicationId $appExists.AppId

            if ($null -eq $servicePrincipalExists) {
                $driftDetected = $true
                New-AzADServicePrincipal -ApplicationId $appExists.AppId -Note $azAdApp.description 1>$null
                Write-Information -MessageData "  UPDATED: created missing AzAd Service Principal"
            } else {
                # ensuring the correct description is set in the note field of the enterprise application
                if ($servicePrincipalExists.Note -ne $azAdApp.description) {
                    $servicePrincipalExists | Update-AzADServicePrincipal -Note $azAdApp.description
                    Write-Information -MessageData "  UPDATED: Service Principal note value has been corrected"
                }
            }

            if ($driftDetected -eq $false) {
                Write-Information -MessageData " SUCCESS: no drift has been detected"
            } else {
                Write-Information -MessageData " Completed drift control, corrections have been applied"
            }
        }
    }
}
