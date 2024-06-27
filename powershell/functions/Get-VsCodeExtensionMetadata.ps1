#Requires -PSEdition Core
<#
    .SYNOPSIS
    Retrieves metadata for a specified Visual Studio Code extension from the Visual Studio Marketplace.

    .DESCRIPTION
    The `Get-VsCodeExtensionMetadata` function queries the Visual Studio Marketplace API to retrieve metadata for a specified VS Code extension.
    The metadata includes the publisher name, extension name, version, and asset URI.
    This function requires an extension ID as input and returns a custom object with the retrieved metadata.

    .PARAMETER ExtensionId
    The unique identifier of the Visual Studio Code extension. This parameter is required.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    The function returns a custom object with the following properties:
    - Publisher: The name of the publisher of the extension.
    - ExtensionName: The name of the extension.
    - Version: The version of the extension.
    - AssetUri: The URI for the extension's assets.

    .EXAMPLE
    PS> $metadata = Get-VsCodeExtensionMetadata -ExtensionId "ms-python.python"
    PS> $metadata
    Publisher     : ms-python
    ExtensionName : python
    Version       : 2023.10.1
    AssetUri      : https://example.com/assetUri

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    The function uses the Visual Studio Marketplace API to retrieve the extension metadata.
    This API is undocumented and may change without notice, use it at your own risk.
#>

function Get-VsCodeExtensionMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $ExtensionId
    )

    try {
        $apiUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=7.2-preview"
        $requestBody = @{
            filters    = @(
                @{
                    criteria = @(
                        @{
                            filterType = 7
                            value      = $ExtensionId
                        }
                    )
                }
            )
            # IncludeLatestVersionOnly (512), IncludeAssetUri (128), IncludeStatistics (16) = 656
            # Details on flags https://learn.microsoft.com/en-us/javascript/api/azure-devops-extension-api/extensionqueryflags?view=azdevops-ext-latest
            flags      = 656
            assetTypes = @("Microsoft.VisualStudio.Services.VSIXPackage")
        } | ConvertTo-Json -Depth 5

        # Invoke the REST API to retrieve the extension metadata.
        $response = Invoke-RestMethod -Uri $apiUrl -Method POST -ContentType "application/json" -Body $requestBody -StatusCodeVariable 'statusCode'

        if ($statusCode -ne 200) {
            throw "Failed to retrieve extension metadata. Http StatusCode: [$statusCode]"
        }

        if (-not $response.results[0].extensions) {
            throw "No extensions found with the ID [$ExtensionId]."
        }

        # Extract the metadata from the response.
        $metadata = [PSCustomObject]@{
            Publisher   = $response.results[0].extensions[0].publisher.publisherName
            Name        = $response.results[0].extensions[0].extensionName
            Version     = $response.results[0].extensions[0].versions[0].version
            DownloadUri = "$($response.results[0].extensions[0].versions[0].assetUri)/Microsoft.VisualStudio.Services.VSIXPackage"
        }

        return $metadata

    } catch {
        Write-Error "Unable to complete request: [$($_.Exception.Message)]"
    }
}
