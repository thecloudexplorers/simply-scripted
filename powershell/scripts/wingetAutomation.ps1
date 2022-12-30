#Requires -PSEdition Desktop
<#
    .SYNOPSIS
    TODO

    .DESCRIPTION
    TODO

    .EXAMPLE
    $currentApps = Get-AzADApplication -DisplayNameStartWith "MyPurposeApps"

    $newOwnerArgs = @{
    AzAdApplicationCollection = $currentApps
    NewOwnerEmail = "devjev@demojev.nl"
    }

    Add-NewApplicationOwnerInBulk @newOwnerArgs

    .NOTES
    Author: Jev - @devjevnl | https://www.devjev.nl
#>

#function MyFunct {
#
[CmdLetBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $WingetConfigFilePath,

    [System.String] $WingetOverrideArgumentsFolderPath,

    [System.Diagnostics.Switch] $UpgradeIfAvailable
)

# Set information level to show output messages
$InformationPreference = 'continue'
$ErrorActionPreference = 'stop'

Write-Information -MessageData "PowerShell version: [$($PSVersionTable.PSVersion)]`n"

Set-Location -Path $PSScriptRoot

if (-not $PSBoundParameters.ContainsKey('WingetOverrideArgumentsFolderPath')) {
    $configFileObject = Get-Item -Path $WingetConfigFilePath
    $infFolder = $configFileObject.Directory.FullName
} else {
    $infFolder = $WingetOverrideArgumentsFolderPath
}

# detecting valid winget installation
Write-Information "Detecting winget installation"
$wingetInstalled = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
Write-Information " winget installation is present"


Write-Information "Uppdating source: winget"
winget source update --name winget
Write-Information " source update complete"

if ($null -ne $wingetInstalled) {
    Write-Information -MessageData "`n Parsing config file at:"
    Write-Information -MessageData "[$WingetConfigFilePath]`n"
    [string]$configContent = Get-Content -Path $WingetConfigFilePath

    # repalce placeholder
    $configContent = $configContent.Replace('###{RootPathPlaceholder}###', $infFolder)
    $configContent = $configContent.Replace('\', '\\')
    $jsonConfigContent = $configContent | ConvertFrom-Json

    $jsonConfigContent.Sources.Packages.ForEach{
        $wgApp = $_

        Write-Information "Checking package [$($wgApp.PackageIdentifier)]"
        $installedPackage = winget list --exact --id $wgApp.PackageIdentifier --accept-source-agreements
        [System.String]$installedPackageString = $installedPackage
        # check if package has NOT been installed
        if ($installedPackageString.Contains('No installed package found matching input criteria.')) {

            # check if override arguments have been passed
            switch ([string]::IsNullOrEmpty($wgApp.overrideArguments)) {
                True {
                    Write-Information "Installing package [$($wgApp.PackageIdentifier)]"
                    winget install --exact --id $wgApp.PackageIdentifier --accept-package-agreements --accept-source-agreements
                    Write-Information -MessageData " installation completed"
                }
                False {
                    Write-Information "Installing package [$($wgApp.PackageIdentifier)] with override arguments"
                    winget install --exact --id $wgApp.PackageIdentifier --override $wgApp.overrideArguments --accept-package-agreements --accept-source-agreements
                    Write-Information -MessageData " installation completed"
                }
                Default {
                    Write-Error -Message "Unable to determine overrideArguments value for this installation, skipping" -ErrorAction Continue
                }
            }
        } else {
            if ($UpgradeIfAvailable.IsPresent) {
                # find the table header line, used to calculate the start of each column
                $headerLineNr = 0
                while (-not $installedPackage[$headerLineNr].StartsWith("Name")) {
                    $headerLineNr++
                }

                # get character index number of the headers, each of which identifies the start of each column in each line
                $versionColumnIndex = $installedPackage[$headerLineNr].IndexOf("Version")
                $sourceColumnIndex = $installedPackage[$headerLineNr].IndexOf("Source")

                $installedPackageLine = $installedPackage[$headerLineNr + 2]
                [System.Double]$installedPackageVersion = $installedPackageLine.Substring($versionColumnIndex, $sourceColumnIndex - $versionColumnIndex).TrimEnd()

                $searchedPackageResult = winget search --exact --id $wgApp.PackageIdentifier --accept-source-agreements --accept-package-agreements
                $searchedPackageLine = $searchedPackageResult[$headerLineNr + 2]

                # since the result from the search command is in the smame format the index values for the columns aare reused
                [System.Double]$searchedPackageVersion = $searchedPackageLine.Substring($versionColumnIndex, $sourceColumnIndex - $versionColumnIndex).TrimEnd()

                if ($installedPackageVersion -lt $searchedPackageVersion) {

                    # check if override arguments have been passed
                    switch ([string]::IsNullOrEmpty($wgApp.overrideArguments)) {
                        True {
                            Write-Information "Upgrading package [$($wgApp.PackageIdentifier)] from version [$installedPackageVersion] to [$searchedPackageVersion]"
                            winget upgrade --exact --id $wgApp.PackageIdentifier --accept-source-agreements --accept-package-agreements
                            Write-Information -MessageData " installation completed"
                        }
                        False {
                            Write-Information "Installing package [$($wgApp.PackageIdentifier)] from version [$installedPackageVersion] to [$searchedPackageVersion] with override arguments"
                            winget upgrade --exact --id $wgApp.PackageIdentifier --override $wgApp.overrideArguments --accept-source-agreements --accept-package-agreements
                            Write-Information -MessageData " installation completed"
                        }
                        Default {
                            Write-Error -Message "Unable to determine overrideArguments value for this installation, skipping" -ErrorAction Continue
                        }
                    }
                } else {
                    Write-Information -MessageData "Current package version [$installedPackageVersion] is the latest available, skipping upgrade"
                }


            } else {
                Write-Information -MessageData "Skipping upgrade check as UpgradeIfAvailable switch has not been passed"
            }
        }
    }
    Write-Information -MessageData " All done!!!"

} else {
    # no valid winget installation detected, handling the error with proper output
    Write-Error -Message "Winget not found, please make sure winget is installed before running this script" -ErrorAction Stop
}
#}

# $myArgs = @{
#     WingetConfigFilePath = "C:\dev\gh\thecloudexplorers\simply-scripted\powershell\scripts\gamejevWingetConfig"
# }

# MyFunct @myArgs
