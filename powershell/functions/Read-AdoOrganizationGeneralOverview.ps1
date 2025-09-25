<#
.SYNOPSIS
    Reads Azure DevOps organization general overview settings and metadata.

.DESCRIPTION
    Queries the Azure DevOps organization overview endpoint to retrieve
    organizational metadata including description, timezone, region, geography,
    and organization owner information. This function provides governance and
    documentation capabilities by assessing whether critical organizational
    settings are properly configured.

    Returns a structured object containing all organization overview data for
    programmatic consumption and reporting purposes.

.PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'devjevnl').

.PARAMETER AdoAuthenticationHeader
    A hashtable containing the Azure DevOps authentication headers for PAT
    usage. Should include 'Content-Type' and 'Authorization' keys, e.g.:
        $patAuthenticationHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Basic ' + $adoAuthToken
        }

.OUTPUTS
    System.Management.Automation.PSCustomObject
        A PSCustomObject with the following properties:
        - Organization: String - The organization name
        - Description: String - Organization description (may be null/empty)
        - TimeZone: String - Display name of the organization's timezone
        - Geography: String - Geographic region
        - Region: String - Specific region within geography
        - Owner: String - Display name of the organization owner
        - DescriptionConfigured: Boolean - Whether description is properly set

.EXAMPLE
    # Create PAT-based auth header and call with splatting
    $adoAuthTokenParams = @{
        PatToken          = $patTokenReadOrganization
        PatTokenOwnerName = $PatTokenOwnerName
    }
    $adoAuthToken = New-AdoAuthenticationToken @adoAuthTokenParams

    $patAuthenticationHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $adoAuthToken
    }

    $params = @{
        Organization            = 'devjevnl'
        AdoAuthenticationHeader = $patAuthenticationHeader
    }
    Read-AdoOrganizationGeneralOverview @params

.NOTES
    WARNING:
    This function uses an internal and undocumented API endpoint.
    This endpoint is not part of the officially supported Azure DevOps REST API.
    Microsoft may change or remove it at any time without notice.

    Endpoints used:
      - Organization Overview (internal):
        https://dev.azure.com/{organization}/_settings/organizationOverview?__rt=fps&__ver=2

    Authentication:
      - Uses PAT via Basic Authorization header

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://github.com/PoshCode/PowerShellPracticeAndStyle
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines
#>
function Read-AdoOrganizationGeneralOverview {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [System.String]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    # Organization overview endpoint (internal API)
    $uri = "https://dev.azure.com/$Organization/_settings/organizationOverview?__rt=fps&__ver=2"

    try {
        # Call the Organization Overview API
        $invokeParams = @{
            Uri             = $uri
            Method          = 'GET'
            Headers         = $AdoAuthenticationHeader
            UseBasicParsing = $true
        }
        $rawResponse = Invoke-WebRequest @invokeParams

        # Check if response content returns a html page which usually indicates token expired
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            Write-Error "Access denied or token expired. Please verify your authentication token is still valid." -ErrorAction Stop
        }

        # Parse JSON response
        $response = $rawResponse.Content | ConvertFrom-Json

        # Extract organization data from the response structure
        $overviewData = $response.fps.dataProviders.data.'ms.vss-admin-web.organization-admin-overview-data-provider'
        $userInfo = $response.fps.dataProviders.data.'ms.vss-web.page-data'.user

        # Build structured result object
        $organizationOverview = [PSCustomObject]@{
            Organization          = $Organization
            Description           = $overviewData.description
            TimeZone              = $overviewData.timeZone.displayName
            Geography             = $overviewData.geography
            Region                = $overviewData.region
            Owner                 = $userInfo.displayName
            DescriptionConfigured = -not [string]::IsNullOrWhiteSpace($overviewData.description)
        }

        # Return the structured result
        return $organizationOverview

    } catch {
        Write-Error "Failed to retrieve organization overview: $($_.Exception.Message)" -ErrorAction Stop
    }
}
