<#
.SYNOPSIS
    Determines whether Advanced Security is enabled for an Azure DevOps organization.

.DESCRIPTION
    This function queries the Azure DevOps Advanced Security API and detects whether the feature is enabled,
    not yet enabled, or enabled but usage data is not available yet.

.PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'devjevnl').

.PARAMETER AccessToken
    A valid Azure DevOps Bearer token with access to organization settings.

.EXAMPLE
    $advSecParams = @{
        Organization = "devjevnl"
        AccessToken  = $token
    }

    Read-AdoOrganizationAdvancedSecurityStatus @advSecParams

.NOTES
    This function uses the internal Azure DevOps endpoint:
    https://advsec.dev.azure.com/{org}/_apis/Management/MeterUsage/Last

    Response types handled:
    - AdvSecNotEnabledForOrgException → Not enabled
    - MeterUsageNotFoundException     → Enabled, no usage yet
    - 200 OK with data                → Enabled and reporting

    Version     : 0.5.1
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/azure/devops/organizations/security/advanced-security-overview
#>
function Read-AdoOrganizationAdvancedSecurityStatus {
    [CmdletBinding()]
    param (
        # Azure DevOps organization name
        [Parameter(Mandatory)]
        [string]$Organization,

        # Valid Bearer token
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "https://advsec.dev.azure.com/$Organization/_apis/Management/MeterUsage/Last?api-version=7.1-preview.1"

    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -UseBasicParsing

        # Token failure fallback
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Try parsing as JSON
        $response = $rawResponse.Content | ConvertFrom-Json

        Write-Host ""
        Write-Host "===== Azure DevOps Advanced Security Status ====="
        Write-Host ""
        Write-Host "Advanced Security is ENABLED for organization: $Organization"
        Write-Host "Usage data is available."
        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        $message = $_.ErrorDetails.Message

        Write-Host ""
        Write-Host "===== Azure DevOps Advanced Security Status ====="
        Write-Host ""

        if ($message -match 'AdvSecNotEnabledForOrgException') {
            Write-Host "Advanced Security is NOT enabled for organization: $Organization"
        } elseif ($message -match 'MeterUsageNotFoundException') {
            Write-Host "Advanced Security is ENABLED but usage data is not yet available for organization: $Organization"
        } else {
            Write-Error "Unexpected error occurred: $($_.Exception.Message)"
            return
        }

        Write-Host ""
        Write-Host "Assessment complete."
    }
}
