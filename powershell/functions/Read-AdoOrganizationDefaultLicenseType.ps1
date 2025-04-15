<#
.SYNOPSIS
    Reads the default license type for new users in an Azure DevOps organization.

.DESCRIPTION
    This function queries the AzComm API to determine the default license type
    assigned to new users (e.g. Basic, Stakeholder) and interprets the numeric value.

.PARAMETER OrganizationId
    The GUID of the Azure DevOps organization (not the display name).

.PARAMETER AccessToken
    A valid Azure DevOps Bearer token with permission to query billing configuration.

.EXAMPLE
    $licenseParams = @{
        OrganizationId = "abb1a1e9-0668-4e42-a4cd-0ca46812949f"
        AccessToken    = $token
    }

    Read-AdoOrganizationDefaultLicenseType @licenseParams

.NOTES
    This function uses the internal Azure DevOps billing API:
    https://azdevopscommerce.dev.azure.com/{orgId}/_apis/AzComm/DefaultLicenseType

    Known values:
    2 = Basic
    5 = Stakeholder

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/commerce/license?view=azure-devops-rest-7.1
#>
function Read-AdoOrganizationDefaultLicenseType {
    [CmdletBinding()]
    param (
        # The GUID of the Azure DevOps organization (not the name)
        [Parameter(Mandatory)]
        [string]$OrganizationId,

        # Valid Bearer token
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/DefaultLicenseType?api-version=7.1-preview.1"

    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -UseBasicParsing

        # Detect expired token or redirect to login
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Parse JSON content
        $response = $rawResponse.Content | ConvertFrom-Json
        $licenseId = $response.defaultLicenseType

        Write-Host ""
        Write-Host "===== Azure DevOps Default License Type Assessment ====="
        Write-Host ""
        Write-Host "Default License Type : [$licenseId]"
        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        Write-Error "Failed to retrieve default license type: [$($_.Exception.Message)]"
    }
}
