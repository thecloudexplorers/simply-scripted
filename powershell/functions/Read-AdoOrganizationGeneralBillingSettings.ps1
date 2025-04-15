<#
.SYNOPSIS
    Reads the general billing settings of an Azure DevOps organization.

.DESCRIPTION
    This function queries the Azure DevOps Commerce (AzComm) API to retrieve general billing
    setup information such as billing status, linked subscription, and account information.
    It also handles cases where billing is not configured.

.PARAMETER OrganizationId
    The GUID of the Azure DevOps organization (not the display name).

.PARAMETER AccessToken
    A valid Azure DevOps Bearer token with permission to query billing details.

.EXAMPLE
    $billingParams = @{
        OrganizationId = "a6c61e95-bc6a-4998-b599-5c1add3fd48b"
        AccessToken    = $token
    }

    Read-AdoOrganizationGeneralBillingSettings @billingParams

.NOTES
    This function uses a documented but lesser-known API endpoint:
    https://azdevopscommerce.dev.azure.com/{orgId}/_apis/AzComm/BillingSetup

    Microsoft may restrict access based on user role or token scope.

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/commerce/billing-setup/read?view=azure-devops-rest-7.1
#>
function Read-AdoOrganizationGeneralBillingSettings {
    [CmdletBinding()]
    param (
        # The GUID of the Azure DevOps organization (not the name)
        [Parameter(Mandatory)]
        [string]$OrganizationId,

        # Valid Bearer token
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/BillingSetup?api-version=7.1-preview.1"

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

        Write-Host ""
        Write-Host "===== Azure DevOps Billing Configuration Assessment ====="
        Write-Host ""

        # Basic identifiers
        Write-Host "Organization Name     : $($response.currentOrganizationName)"
        Write-Host "Subscription Status   : $($response.subscriptionStatus)"
        Write-Host "Enterprise Billing    : $($response.isEnterpriseBillingEnabled)"
        Write-Host "Assignment Billing    : $($response.isAssignmentBillingEnabled)"

        # Check if billing is configured (based on key presence)
        if ($response.PSObject.Properties.Name -contains 'billingPlanId') {
            Write-Host "Billing Active        : $($response.isActive)"
            Write-Host "Billing Plan ID       : $($response.billingPlanId)"
            Write-Host "Subscription ID       : $($response.subscriptionId)"
            Write-Host "Billing Account ID    : $($response.billingAccountId)"
            Write-Host "Marketplace Publisher : $($response.marketplacePublisher)"
        } else {
            Write-Host "Billing is not currently configured for this organization."
        }

        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        Write-Error "Failed to retrieve billing configuration: $($_.Exception.Message)"
    }
}
