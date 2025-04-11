<#
    .SYNOPSIS
    Performs an assessment of Azure DevOps organization overview settings.

    .DESCRIPTION
    This function queries the internal Azure DevOps organization overview endpoint
    and retrieves metadata including the description, timezone, region, geography,
    and organization owner. It checks whether the description field is populated
    and reports the other fields for governance and documentation purposes.

    .PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'contoso').

    .PARAMETER AccessToken
    A valid Azure DevOps Bearer token with access to read organization-level settings.

    .EXAMPLE
    Invoke-AdoOrganizationOverviewAssessment -Organization "demojev" -AccessToken $token

    .NOTES
    WARNING: This function uses an internal and undocumented API endpoint:
             https://dev.azure.com/{org}/_settings/organizationOverview?__rt=fps&__ver=2

             This endpoint is not part of the officially supported Azure DevOps REST API.
             Microsoft may change or remove it at any time without notice.

             The function includes logic to detect expired or invalid Bearer tokens
             based on HTML fallback content.

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://github.com/PoshCode/PowerShellPracticeAndStyle
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines
#>
function Read-AdoOrganizationGeneralOverview {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $Organization,

        [Parameter(Mandatory)]
        [System.String] $AccessToken
    )

    $uri = "https://dev.azure.com/$Organization/_settings/organizationOverview?__rt=fps&__ver=2"

    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {
        Write-Host
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -UseBasicParsing

        # Detect HTML response indicating token failure
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Parse JSON only if response is valid
        $response = $rawResponse.Content | ConvertFrom-Json

        $overviewData = $response.fps.dataProviders.data.'ms.vss-admin-web.organization-admin-overview-data-provider'
        $userInfo = $response.fps.dataProviders.data.'ms.vss-web.page-data'.user

        $description = $overviewData.description
        $timeZone = $overviewData.timeZone.displayName
        $geography = $overviewData.geography
        $region = $overviewData.region
        $owner = $userInfo.displayName

        Write-Host ""
        Write-Host "===== Azure DevOps Organization Overview Assessment ====="
        Write-Host ""

        if ([string]::IsNullOrWhiteSpace($description)) {
            Write-Host "Description: (not set)"
        } else {
            Write-Host "Description: $description"
        }

        Write-Host "Time Zone : $timeZone"
        Write-Host "Geography : $geography"
        Write-Host "Region    : $region"
        Write-Host "Owner     : $owner"
        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        Write-Error "Failed to retrieve organization overview: $($_.Exception.Message)"
    }
}
