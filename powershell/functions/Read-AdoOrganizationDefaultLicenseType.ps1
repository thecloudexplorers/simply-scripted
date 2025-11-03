<#
.SYNOPSIS
    Reads the default license type for new users in an Azure DevOps
    organization.

.DESCRIPTION
    Queries the Azure DevOps Commerce API to obtain the default
    license type assigned to new users when they are added to an organization.

.PARAMETER OrganizationId
    The GUID identifier of the Azure DevOps organization. This is NOT the
    organization name! Use Get-AdoOrganizationId.ps1 to retrieve
    it.

.PARAMETER AdoBearerBasedAuthenticationHeader
    A hashtable containing the Authorization header for the request, e.g.
    @{ Authorization = "Bearer <access-token>" }. This header must be valid and
    have the required permissions to read organization-level settings.

.EXAMPLE
    $licenseParams = @{
        OrganizationId                      = "abb1a1e9-0668-4e42-a4cd-0ca46812949f"
        AdoBearerBasedAuthenticationHeader = @{ Authorization = "Bearer $token" }
    }
    Read-AdoOrganizationDefaultLicenseType @licenseParams

.OUTPUTS
    System.String
        Returns a string representing the default license type.
        - Stakeholder
        - Basic
        - Visual Studio Subscriber.

.NOTES
    WARNING:
    This function uses an internal and undocumented API endpoint.
    This endpoint is not part of the officially supported Azure DevOps REST API.
    Microsoft may change or remove it at any time without notice.

    https://azdevopscommerce.dev.azure.com/{orgId}/_apis/AzComm/DefaultLicenseType?api-version=7.1-preview.1"

    Authentication:
      - Uses a Bearer token Authorization header

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Read-AdoOrganizationDefaultLicenseType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $OrganizationId,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $AdoBearerBasedAuthenticationHeader
    )

    $defaultLicenseTypeUri = "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/DefaultLicenseType?api-version=7.1-preview.1"

    $invokeParams = @{
        Uri             = $defaultLicenseTypeUri
        Method          = 'GET'
        Headers         = $AdoBearerBasedAuthenticationHeader
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }

    try {
        $restResponse = Invoke-RestMethod @invokeParams

        # Check if response content returns a html page which usually indicates token expired
        if ($restResponse -match '<html' -or $restResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        Write-Information -MessageData "Default License Type Value: [$($restResponse.defaultLicenseType)]"
        $licenseType = $restResponse.defaultLicenseType

        return $licenseType
    } catch {
        Write-Error "Failed to retrieve default license type: [$($_.Exception.Message)]"
    }
}
