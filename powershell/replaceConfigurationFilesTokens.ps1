#Requires -PSEdition Core
<#
    .SYNOPSIS
    This script processes configuration files within specified folders,
    replacing token placeholders with their corresponding values.

    .DESCRIPTION
    The script scans a root folder for subdirectories containing configuration files.
    It processes these files by replacing tokens defined between start and end token
    patterns with values from a metadata.jsonc file which must be present in the same
    folder as the tokenized files. Additionally, if the switch
    `ExtractTokenValueFromConfigFileName` is used, it extracts a token value from the
    configuration file name and adds it to the metadata.

    .PARAMETER RootRepoLocation
    The root repository location where the script is located.

    .PARAMETER ConfigFilesRootFolder
    The root folder containing subdirectories with configuration files to be processed.

    .PARAMETER CustomOutputFolderPath
    An optional parameter specifying a custom output folder path where the processed
    files will be saved. If not specified, the original files will be modified.

    .PARAMETER StartTokenPattern
    The pattern indicating the start of a token in the configuration files.

    .PARAMETER EndTokenPattern
    The pattern indicating the end of a token in the configuration files.

    .PARAMETER ExtractTokenValueFromConfigFileName
    A switch that, when used, indicates that a token value should be extracted
    from the configuration file name.

    .PARAMETER PrefixForConfigFileNameWithTokenValue
    The prefix used to identify configuration files from which a token value
    should be extracted. Required if `ExtractTokenValueFromConfigFileName` is used.

    .PARAMETER TargetTokenNameForTokenValueFromConfigFileName
    The name of the token in the metadata to which the extracted value should be assigned.
    Required if `ExtractTokenValueFromConfigFileName` is used.

    .EXAMPLE
    # Example usage with splatting
    $params = @{
        RootRepoLocation                          = "C:\Repo"
        ConfigFilesRootFolder                     = "C:\Config"
        CustomOutputFolderPath                    = "C:\Output"
        StartTokenPattern                         = "START"
        EndTokenPattern                           = "END"
        ExtractTokenValueFromConfigFileName       = $true
        PrefixForConfigFileNameWithTokenValue     = "Prefix"
        TargetTokenNameForTokenValueFromConfigFileName = "TokenName"
    }
    .\replaceConfigurationFilesTokens.ps1 @params

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $RootRepoLocation,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $ConfigFilesRootFolder,

    [ValidateNotNullOrEmpty()]
    [System.String] $CustomOutputFolderPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $StartTokenPattern,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $EndTokenPattern,

    [Parameter(ParameterSetName = "TokenValueFromConfigFileName")]
    [System.Management.Automation.SwitchParameter] $ExtractTokenValueFromConfigFileName,

    [Parameter(ParameterSetName = "TokenValueFromConfigFileName")]
    [System.String] $PrefixForConfigFileNameWithTokenValue,

    [Parameter(ParameterSetName = "TokenValueFromConfigFileName")]
    [System.String] $TargetTokenNameForTokenValueFromConfigFileName
)

# Set errors to break script execution
$ErrorActionPreference = 'Stop'

# Load Write-ConsoleLogMessage function via dot sourcing
Write-Host "Importing Convert-TokensToValues.ps1"
$convertTokensToValues = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\Convert-TokensToValues.ps1"
. $convertTokensToValues

if ([string]::IsNullOrEmpty($CustomOutputFolderPath) -eq $false) {
    Write-Information -MessageData "Custom output folder has been specified, original files will remain unmodified"
    Write-Information -MessageData "Output folder: [$CustomOutputFolderPath] `n"
}

# Get sub-folders with config files
$currentConfigFoldersCollection = Get-ChildItem -Path $ConfigFilesRootFolder -Attributes Directory | Sort-Object -Property FullName

$currentConfigFoldersCollection.ForEach{
    $currentConfigFolder = $_

    Write-Host "Processing folder [$($currentConfigFolder.Name)]"
    $configFilesCollection = Get-ChildItem -Path $currentConfigFolder -Attributes !Directory | Where-Object { $_.Name -ne 'metadata.jsonc' }
    if ($null -eq $configFilesCollection) {
        Write-Host -ForegroundColor Yellow " Tokenized configuration files are missing, skipping processing"
    }

    $metadataFile = Get-ChildItem -Path $currentConfigFolder -Attributes !Directory | Where-Object { $_.Name -eq 'metadata.jsonc' }
    if ($null -eq $metadataFile) {
        Write-Host -ForegroundColor Yellow " Metadata.jsonc file is missing, skipping processing"
    }

    # Ensure config files are present and metadata file is present, if not skip processing
    if ($null -ne $configFilesCollection -and $null -ne $metadataFile) {
        # Iterating config files collection
        $configFilesCollection.ForEach{
            $currentConfigFile = $_

            Write-Host " Processing config file [$($currentConfigFile.Name)]"
            $metadataFileContent = Get-Content -Path $metadataFile.FullName
            [System.Collections.Hashtable] $metadata = $null
            $metadata = $metadataFileContent | ConvertFrom-Json -AsHashtable

            if ($ExtractTokenValueFromConfigFileName.IsPresent) {
                Write-Host " Extracting token value from filename"
                if ($currentConfigFile.Name.Contains($PrefixForConfigFileNameWithTokenValue)) {
                    Write-Host " Processing config file [$($currentConfigFile.Name)]"
                    $tokenValueFromConfigFileName = $currentConfigFile.Name.Split('-')[1].Split('.')[0]

                    Write-Debug "Adding key [$TargetTokenNameForTokenValueFromConfigFileName] with value [$tokenValueFromConfigFileName] to metadata hashtable"
                    $metadata.Add($TargetTokenNameForTokenValueFromConfigFileName, $tokenValueFromConfigFileName)
                }
            }

            # Check if custom output folder is specified, if so ensure the file is saved in that folder
            [System.String] $outputPath = $null
            if ([string]::IsNullOrEmpty($CustomOutputFolderPath) -eq $false) {
                # Split current config file path into its folder structure
                $currentConfigFilePathCollection = $currentConfigFile.FullName.Split('\')
                # Get the config files folder name
                $configFolderName = $currentConfigFilePathCollection[$currentConfigFilePathCollection.Count - 2]
                # Recreate the folder structure in the custom output folder
                $outputFolder = "{0}\{1}" -f $CustomOutputFolderPath, $configFolderName
                # add the file name to complete teh full filepath in the new folder
                $outputPath = "{0}\{1}\{2}" -f $CustomOutputFolderPath, $configFolderName, $currentConfigFile.Name

                # Ensure the config folder exists in the custom output folder
                if (-not $(Test-Path -Path $outputFolder)) {
                    New-Item -ItemType Directory -Path $outputFolder 1> $null
                }

            } else {
                $outputPath = $currentConfigFile.FullName
            }

            $tokensToValuesArgs = @{
                MetadataCollection   = $metadata
                TargetFilePath       = $currentConfigFile.FullName
                CustomOutputFilePath = $outputPath
                StartTokenPattern    = $StartTokenPattern
                EndTokenPattern      = $EndTokenPattern
            }

            # Replace tokens with values in the config file
            Convert-TokensToValues @tokensToValuesArgs
            Write-Host " Config file has been processed `n"
        }
    }
    Write-Host "Folder has been processed `n"
}
