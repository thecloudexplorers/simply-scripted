<#
.SYNOPSIS
    Determines whether Advanced Security is enabled for an Azure DevOps organization.

.DESCRIPTION
    This function queries the Azure DevOps Advanced Security API and detects whether Advanced Security
    is enabled for the organization. It handles three scenarios:
    - Advanced Security is enabled and usage data is returned
    - Advanced Security is enabled but usage data is not yet available
    - Advanced Security is not enabled at all

    If enabled and reporting, the function outputs billing date, unique committer count,
    and billed user identities.

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
    - 200 OK with usage data            → Advanced Security is enabled
    - MeterUsageNotFoundException       → Enabled but usage data is not yet available
    - AdvSecNotEnabledForOrgException   → Not enabled

    Version     : 0.6.0
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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    $meterUsageUri = "https://advsec.dev.azure.com/$Organization/_apis/Management/MeterUsage/Last?api-version=7.1-preview.1"

    try {
        $rawResponse = Invoke-WebRequest -Uri $meterUsageUri -Method Get -Headers $AdoAuthenticationHeader -UseBasicParsing

        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        $response = $rawResponse.Content | ConvertFrom-Json

        Write-Host ""
        Write-Host "===== Azure DevOps Advanced Security Status ====="
        Write-Host ""

        if ($response.isAdvSecEnabled -eq $true) {
            Write-Host "Advanced Security is ENABLED for organization: $Organization"
            Write-Host "Billing Date             : $($response.billingDate)"
            Write-Host "Billable Status          : $($response.isAdvSecBillable)"
            Write-Host "Unique Committer Count   : $($response.uniqueCommitterCount)"

            if ($response.billedUsers) {
                Write-Host "Billed Users:"
                foreach ($user in $response.billedUsers) {
                    Write-Host "  - $($user.userIdentity.displayName)"
                }
            }
        } else {
            Write-Host "Advanced Security is NOT enabled for organization: $Organization"
        }

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
        }

        Write-Host ""
        Write-Host "Assessment complete."
    }
}
