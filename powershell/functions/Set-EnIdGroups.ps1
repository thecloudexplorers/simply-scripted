#requires -Modules Az.Resources
<#
    .SYNOPSIS
    Creates Entra ID Security Groups in bulk. And applies basic drift control

    .DESCRIPTION
    This function creates creates Entra ID Security Groups .
    It also applies drift control on the description field of the security
    groups in question.

    .PARAMETER EnIdGroups
    A collection Entra ID Groups objects to create

    .EXAMPLE
    $EnIdAppsArgs = @{
        InIdApps = [System.Object[]] $enIdApplicationsColl
    }
    New-InIdApps @InIdAppsArgs

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://learn.microsoft.com/en-us/powershell/module/Az.Resources/new-azadapplication
#>

function Set-EnIdGroups {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]] $EnIdGroups
    )

    $EnIdGroups.ForEach{
        $enIdGroup = $_

        # Ensuring the description is not $null as an $null value is not accepted during creation
        if ([string]::IsNullOrEmpty($enIdApp.description)) {
            $enIdGroup.description = " "
        }

        $groupExists = Get-AzADGroup -Filter "DisplayName eq '$($enIdGroup.name)'"

        if ($null -eq $groupExists) {
            Write-Host " Creating Entra ID Group [$($enIdGroup.name)]"
            $groupParams = @{
                DisplayName     = $enIdGroup.name
                MailNickname    = $enIdGroup.name
                Description     = $enIdGroup.description
                SecurityEnabled = $true
            }

            $groupExists = New-AzADGroup @groupParams
            Write-Host " Group has been created"

        } else {
            Write-Host " Entra ID Group [$($enIdGroup.name)] is already present, applying drift control"
            [System.Boolean]$driftDetected = $false

            # Ensuring the correct description is set in the note field of the application
            if ($groupExists.Description -ne $enIdGroup.description) {
                $driftDetected = $true
                $groupExists | Update-AzADGroup -Description $enIdGroup.description
                Write-Host "  UPDATED: Group description value has been corrected"
            }

            if ($driftDetected -eq $false) {
                Write-Host " SUCCESS: no drift has been detected"
            } else {
                Write-Host " Completed drift control, corrections have been applied"
            }
        }
    }
}
