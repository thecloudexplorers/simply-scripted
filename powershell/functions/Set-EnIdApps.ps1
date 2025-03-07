#requires -Modules Az.Resources
<#
    .SYNOPSIS
    Creates Entra ID App Registrations in bulk (application). And applies basic
    drift control

    .DESCRIPTION
    This function creates an Creates an Entra ID App Registration and a
    corresponding Enterprise application. It also applies drift control on the
    description field of the application and enterprise application.

    .PARAMETER EnIdApps
    A collection Entra ID Application objects to create

    .EXAMPLE
    Object example:
    "enIdApplications": [
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

    $EnIdAppsArgs = @{
        InIdApps = enIdApplictionsColl
    }
    New-InIdApps @InIdAppsArgs

    .NOTES
    Version     : 2.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://learn.microsoft.com/en-us/powershell/module/Az.Resources/new-azadapplication
#>

function Set-EnIdApps {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]] $EnIdApps
    )

    $EnIdApps.ForEach{
        $enIdApp = $_

        # Ensuring the description is not $null as an $null value is not accepted during creation
        if ([string]::IsNullOrEmpty($enIdApp.description)) {
            $enIdApp.description = " "
        }

        $appExists = Get-AzADApplication -Filter "DisplayName eq '$($enIdApp.name)'"

        if ($null -eq $appExists) {
            Write-Host " Creating Entra ID Application [$($enIdApp.name)]"
            $newApp = New-AzADApplication -DisplayName $enIdApp.name -Note $enIdApp.description

            # Create a corresponding enterprise application for the app registration in question
            Write-Host "  Creating Entra ID Service Principal for the concerning Entra ID Application"
            New-AzADServicePrincipal -ApplicationId $newApp.AppId -Note $enIdApp.description 1>$null
            Write-Host "  Entra ID Service Principal has been created"
            Write-Host " Application has been created"

        } else {
            Write-Host " Entra ID Application [$($enIdApp.name)] is already present, applying drift control"
            [System.Boolean]$driftDetected = $false

            # Ensuring the correct description is set in the note field of the application
            if ($appExists.Note -ne $enIdApp.description) {
                $driftDetected = $true
                $appExists | Update-AzAdApplication -Note $enIdApp.description
                Write-Host "  UPDATED: Application note value has been corrected"
            }

            # Ensuring enterprise application is present
            $servicePrincipalExists = Get-AzADServicePrincipal -ApplicationId $appExists.AppId

            if ($null -eq $servicePrincipalExists) {
                $driftDetected = $true
                New-AzADServicePrincipal -ApplicationId $appExists.AppId -Note $enIdApp.description 1>$null
                Write-Host "  UPDATED: created missing Entra ID Service Principal"
            } else {
                # Ensuring the correct description is set in the note field of the enterprise application
                if ($servicePrincipalExists.Note -ne $enIdApp.description) {
                    $servicePrincipalExists | Update-AzADServicePrincipal -Note $enIdApp.description
                    Write-Host "  UPDATED: Service Principal note value has been corrected"
                }
            }

            if ($driftDetected -eq $false) {
                Write-Host " SUCCESS: no drift has been detected"
            } else {
                Write-Host " Completed drift control, corrections have been applied"
            }
        }
    }
}
