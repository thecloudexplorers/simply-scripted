<#
.SYNOPSIS
    Reads and verifies the general billing settings of an Azure DevOps
    organization.

.DESCRIPTION
    This function queries the Azure DevOps Commerce (AzComm) API to retrieve
    general billing setup information such as billing status, subscription ID,
    and account settings.If billing is configured, it also verifies that the
    subscription ID matches the expected one.

.PARAMETER OrganizationId
    The GUID of the Azure DevOps organization (not the display name).

.PARAMETER AccessToken
    A valid Azure DevOps Bearer token with permission to query billing details.

.PARAMETER ExpectedSubscriptionId
    (Optional) The expected Azure subscription ID to compare against the billing
    setup.

.EXAMPLE
    $billingParams = @{
        OrganizationId         = "a6c61e95-bc6a-4998-b599-5c1add3fd48b"
        AccessToken            = $token
        ExpectedSubscriptionId = "6f1ae004-9078-4e65-8424-fe70a5aaaedc"
    }

    Read-AdoOrganizationGeneralBillingSettings @billingParams

.NOTES
    API: https://azdevopscommerce.dev.azure.com/{orgId}/_apis/AzComm/BillingSetup

    Version     : 0.6.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Read-AdoOrganizationGeneralBillingSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]$OrganizationId,

        [Parameter(Mandatory)]
        [System.String]$AccessToken,

        [Parameter()]
        [System.String]$ExpectedSubscriptionId
    )

    $uri = "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/BillingSetup?api-version=7.1-preview.1"

    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -UseBasicParsing

        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        $response = $rawResponse.Content | ConvertFrom-Json

        Write-Host ""
        Write-Host "===== Azure DevOps Billing Configuration Assessment ====="
        Write-Host ""

        Write-Host "Organization Name     : $($response.currentOrganizationName)"
        Write-Host "Subscription Status   : $($response.subscriptionStatus)"
        Write-Host "Enterprise Billing    : $($response.isEnterpriseBillingEnabled)"
        Write-Host "Assignment Billing    : $($response.isAssignmentBillingEnabled)"

        if ($response.PSObject.Properties.Name -contains 'subscriptionId' -and $response.subscriptionId) {
            Write-Host "Subscription ID       : $($response.subscriptionId)"

            if ($ExpectedSubscriptionId) {
                if ($response.subscriptionId -eq $ExpectedSubscriptionId) {
                    Write-Host "Subscription ID match : Expected subscription ID matches actual."
                } else {
                    Write-Host "Subscription ID match : Mismatch. Expected: [$ExpectedSubscriptionId]"
                }
            }

            Write-Host "Billing is configured."
        } else {
            Write-Host "Billing is not currently configured for this organization."
        }

        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        Write-Error "Failed to retrieve billing configuration: $($_.Exception.Message)"
    }
}
