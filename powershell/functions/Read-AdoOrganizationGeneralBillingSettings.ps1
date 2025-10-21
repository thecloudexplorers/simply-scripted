<#
.SYNOPSIS
    Retrieves and validates general billing settings for an Azure DevOps org.

.DESCRIPTION
    Queries the Azure DevOps Commerce (AzComm) API to obtain billing setup info
    for the specified organization. Returns a PSCustomObject containing the
    subscription id, subscription status, last updated timestamp and a computed
    BillingType (Enterprise / Assignment / Not Configured). Detects HTML or
    sign-in responses and surfaces an access denied / token expired error.
    Informational messages are written for the current subscription, billing
    status and last updated timestamp.

.PARAMETER OrganizationId
    The GUID of the Azure DevOps organization (not the display name). This value
    is used in the AzComm BillingSetup API request.

.PARAMETER AdoBearerBasedAuthenticationHeader
    A hashtable containing the Authorization header for the request, e.g.
    @{ Authorization = "Bearer <access-token>" }. This header must be valid and
    have the required permissions to query billing details.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Properties:
      - AzureSubscriptionId     : (string) Subscription ID used for billing.
      - AzureSubscriptionStatus : (string) Billing subscription status.
      - UpdatedDateTime         : (string/datetime) Last update timestamp.
      - BillingType             : (string) Computed billing type: Enterprise,
                                  Assignment or Not Configured.

.EXAMPLE
    $bearerHeader = @{ Authorization = "Bearer $env:AZDEVOPS_ACCESS_TOKEN" }
    $params = @{
        OrganizationId                      = "00000000-0000-0000-0000-000000000000"
        AdoBearerBasedAuthenticationHeader  = $bearerHeader
    }
    Read-AdoOrganizationGeneralBillingSettings @params

.NOTES
    API: https://azdevopscommerce.dev.azure.com/{orgId}/_apis/AzComm/BillingSetup?
          api-version=7.1-preview.1

    Version : 0.6.1
    Author  : Jev - @devjevnl | https://www.devjev.nl
    Source  : https://github.com/thecloudexplorers/simply-scripted
#>
function Read-AdoOrganizationGeneralBillingSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $OrganizationId,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $AdoBearerBasedAuthenticationHeader
    )

    $billingSetupUri = "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/BillingSetup?api-version=7.1-preview.1"

    $invokeParams = @{
        Uri             = $billingSetupUri
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

        # console output in case information preference is set to include Information stream
        Write-Information -MessageData "Current Azure Subscription used for billing: [$($restResponse.subscriptionId)]"
        Write-Information -MessageData "Billing Status: [$($restResponse.subscriptionStatus)]"
        Write-Information -MessageData "Last Updated: [$($restResponse.updatedDateTime)]"

        # Determine billing type
        $billingType = switch ($true) {
            $restResponse.isEnterpriseBillingEnabled { 'Enterprise'; break }
            $restResponse.isAssignmentBillingEnabled { 'Assignment'; break }
            Default { 'Not Configured' }
        }

        # Create result object
        $result = [PSCustomObject]@{
            AzureSubscriptionId     = $restResponse.subscriptionId
            AzureSubscriptionStatus = $restResponse.subscriptionStatus
            UpdatedDateTime         = $restResponse.updatedDateTime
            BillingType             = $billingType
        }

        # return billing details
        return $result
    } catch {
        Write-Error "Failed to retrieve billing configuration: $($_.Exception.Message)"
    }
}
