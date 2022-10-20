#Requires -PSEdition Desktop

[CmdLetBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $WingetConfigFilePath,

    [System.String] $WingetOverrideArgumentsFolderPath
)

Write-Information -MessageData "PowerShell version: [$($PSVersionTable.PSVersion)]`n"

Set-Location -Path $PSScriptRoot

# Set information level to show output messages
$InformationPreference = 'continue'
$ErrorActionPreference = 'stop'

if (-not $PSBoundParameters.ContainsKey('WingetOverrideArgumentsFolderPath')) {
    $configFileObject = Get-Item -Path $WingetConfigFilePath
    $infFolder = $configFileObject.Directory.FullName
}
else {
    $infFolder = $WingetOverrideArgumentsFolderPath
}

# detecting valid winget installation
Write-Information "Detecting winget installation"
$wingetInstalled = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'

if ($nukll -ne $wingetInstalled) {
    Write-Information -MessageData "Parsing config file"
    Write-Information -MessageData "[$WingetConfigFilePath]`n"
    [string]$configContent = Get-Content -Path $WingetConfigFilePath

    # repalce placeholder
    $configContent = $configContent.Replace('###{RootPathPlaceholder}###', $infFolder)
    $configContent = $configContent.Replace('\', '\\')
    $jsonConfigContent = $configContent | ConvertFrom-Json

    $jsonConfigContent.ForEach{
        $wgApp = $_

        # check if override arguments have bene passed
        switch ([string]::IsNullOrEmpty($wgApp.overrideArguments)) {
            True {
                Write-Information "Installing package [$($wgApp.appId)]"
                winget install --exact --id $wgApp.appId
                Write-Information -MessageData " installation completed"
            }
            False {
                Write-Information "Installing package [$($wgApp.appId)] with override arguments"
                winget install --exact --id $wgApp.appId --override $wgApp.overrideArguments
                Write-Information -MessageData " installation completed"
            }
            Default {
                Write-Error -Message "Unable to determine overrideArguments value for this installation, skipping" -ErrorAction Continue
            }
        }

    }
    Write-Information -MessageData " All done!!!"

}
else {
    # no valid winget installation detected, handling the error with proper output
    Write-Error -Message "Winget not found, please make sure winget is installed before running this script" -ErrorAction Stop
}
