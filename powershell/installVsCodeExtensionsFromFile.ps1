
# Dot-sourcing the Get-VsCodeExtensionMetadata function
. powershell\functions\Get-VsCodeExtensionMetadata.ps1

# Define the path to the extensions.json file
#$extensionsFilePath = Join-Path $HOME ".vscode/extensions/extensions.json"
$extensionsFilePath = "C:/Temp/VsCodeExtensions/extensions.json"

# Check if the file exists
if (-Not (Test-Path $extensionsFilePath)) {
    Write-Error -Exception "The file extensions.json does not exist at the specified path: $extensionsFilePath" -ErrorAction Stop
}

# Read the content of the extensions.json file
$extensionsContent = Get-Content $extensionsFilePath -Raw

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

    $currentInstalledExtensions | Where-Object { $_.Split('@')[0] -eq $currentExtension.identifier.id }

    $extensionInstalled = $currentInstalledExtensions | Where-Object { $_.StartsWith( $currentExtension.identifier.id) }
    if ($null -eq $extensionInstalled) {
        Write-Information "Extension [$($currentExtension.identifier.id)] is already installed"
        $versionUpToDate = $extensionInstalled.Split('@')[1] -eq $currentExtension.version
    }
    if ($versionUpToDate) {
        Write-Information "Extension version is also up to date, skipping installation"
    } else {
        $extensionMetadata = Get-VsCodeExtensionMetadata -ExtensionId $currentExtension.identifier.id
        Write-Information "Imported extension [$($currentExtension.identifier.id)] market place metadata"

        # compose a file name for the .vsix file
        $composedFileName = "{0}_{1}_{2}.VSIX" -f $extensionMetadata.Publisher, $extensionMetadata.Name, $extensionMetadata.Version
        $fullFilePath = "{0}{1}" -f $vsixOutDirectory, $composedFileName

        # Download the .vsix file
        Invoke-WebRequest -Uri $extensionMetadata.DownloadUri -OutFile $fullFilePath
        Write-Information "Downloaded extension [$($extensionMetadata.Name)] to [$vsixOutDirectory]"

        $destinationPath = Join-Path $vsixDirectory $fileName
        Invoke-Expression "code --install-extension `"$destinationPath`""

    }
}
