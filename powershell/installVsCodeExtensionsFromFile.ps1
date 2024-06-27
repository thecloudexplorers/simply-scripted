#Requires -PSEdition Core
<#
    .SYNOPSIS
    This script manages Visual Studio Code extensions by installing or updating them based on a provided JSON file.

    .DESCRIPTION
    The script reads a JSON file containing details about desired Visual Studio Code extensions.
    It checks whether these extensions are already installed and up-to-date.
    If an extension is not installed or is outdated, the script downloads the appropriate .vsix file and installs or updates the extension.
    The script also creates a temporary directory to store the downloaded .vsix files if it does not already exist.

    .PARAMETER ExtensionsJsonFilePath
    The path to the JSON file containing the extensions' details. This parameter is mandatory.

    .EXAMPLE
    .\Manage-VsCodeExtensions.ps1 -ExtensionsJsonFilePath "C:\path\to\extensions.json"
    This example reads the extensions.json file located at "C:\path\to\extensions.json" and manages the VS Code extensions accordingly.

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    Dependencies: Get-VsCodeExtensionMetadata.ps1 function file must be present in the specified path.
#>

# [CmdletBinding()]
# param (
#     [Parameter(Mandatory)]
#     [System.String] $ExtensionsJsonFilePath
# )

$ExtensionsJsonFilePath = "C:\Temp\VsCodeExtensions\extensions.json"
$InformationPreference = 'Continue'

# Dot-sourcing the Get-VsCodeExtensionMetadata function
Write-Information "Dot-sourcing the Get-VsCodeExtensionMetadata.ps1 function file"
. powershell\functions\Get-VsCodeExtensionMetadata.ps1

# Check if the file exists
if (-Not (Test-Path $ExtensionsJsonFilePath)) {
    Write-Error -Exception "The file extensions.json does not exist at the specified path: [$ExtensionsJsonFilePath]" -ErrorAction Stop
}

# Read the content of the extensions.json file
$extensionsContent = Get-Content $ExtensionsJsonFilePath -Raw

# Parse the JSON content
$extensionsJson = $extensionsContent | ConvertFrom-Json -Depth 5

# Create a temp directory to save the .vsix files
$vsixOutDirectory = "C:\temp\VsCodeExtensions\"
if (-Not (Test-Path $vsixOutDirectory)) {
    New-Item -ItemType Directory -Path $vsixOutDirectory 1> $null
}

$currentInstalledExtensions = Invoke-Expression "code --list-extensions --show-versions"

$extensionsJson.ForEach{
    $currentExtension = $_

    Write-Information "Processing extension [$($currentExtension.identifier.id)]"
    # Skip extensions that are not from the Visual Studio Code marketplace
    if (-not $currentExtension.identifier.id.StartsWith("vscode.")) {
        $currentInstalledExtensions | Where-Object { $_.Split('@')[0] -eq $currentExtension.identifier.id }
        $extensionInstalled = $currentInstalledExtensions | Where-Object { $_.StartsWith( $currentExtension.identifier.id) }
        if ($null -eq $extensionInstalled) {
            Write-Information "Extension [$($currentExtension.identifier.id)] is not installed"
            # TODO: EXtend this part to include functionality for updating out of date versions
            #$versionUpToDate = $extensionInstalled.Split('@')[1] -eq $currentExtension.version

            $extensionMetadata = Get-VsCodeExtensionMetadata -ExtensionId $currentExtension.identifier.id
            Write-Information "Imported extension [$($currentExtension.identifier.id)] market place metadata"

            # Compose a file name for the .vsix file
            $composedFileName = "{0}_{1}_{2}.VSIX" -f $extensionMetadata.Publisher, $extensionMetadata.Name, $extensionMetadata.Version
            $fullFilePath = "{0}{1}" -f $vsixOutDirectory, $composedFileName

            # Download the .vsix file
            Invoke-WebRequest -Uri $extensionMetadata.DownloadUri -OutFile $fullFilePath
            Write-Information "Downloaded extension [$($extensionMetadata.Name)] to [$vsixOutDirectory]"

            # install the extension
            $expressionOut = Invoke-Expression "code --install-extension `"$fullFilePath`""
            $expressionOut.ForEach{
                Write-Information $_
            }
        } else {
            Write-Information "Extension [$($currentExtension.identifier.id)] is already installed"
        }
    } else {
        Write-Information "Extension [$($currentExtension.identifier.id)] is not from the Visual Studio Code marketplace, skipping"
    }
}
