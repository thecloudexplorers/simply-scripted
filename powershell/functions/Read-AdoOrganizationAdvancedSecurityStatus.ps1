<#
.SYNOPSIS
    Determines whether Advanced Security is enabled for an Azure DevOps
    organization.

.DESCRIPTION
    This function queries the Azure DevOps Advanced Security API and detects
    whether Advanced Security is enabled for the organization. It handles three
    scenarios:
    - Advanced Security is enabled and usage data is returned
    - Advanced Security is enabled but usage data is not yet available
    - Advanced Security is not enabled at all

    If enabled and reporting, the function outputs billing date, billable
    status, and billed user identities. The function also checks for token
    expiration and access errors.

.PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'devjevnl').

.PARAMETER AdoAuthenticationHeader
    A hashtable containing the Azure DevOps authentication headers for PAT
    usage. Should include 'Content-Type' and 'Authorization' keys, e.g.:
    Example:
        $patAuthenticationHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Basic ' + $adoAuthToken
        }

.EXAMPLE
    $adoAuthTokenParams = @{
        PatToken         = $patTokenReadAdvancedSecurity
        PatTokenOwnerName = $PatTokenOwnerName
    }
    $adoAuthToken = New-AdoAuthenticationToken @adoAuthTokenParams

    $patAuthenticationHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $adoAuthToken
    }
    $params = @{
        Organization           = "devjevnl"
        AdoAuthenticationHeader = $patAuthenticationHeader
    }
    Read-AdoOrganizationAdvancedSecurityStatus @params

    Read-AdoOrganizationAdvancedSecurityStatus @advSecParams

.NOTES
    This function uses the internal Azure DevOps endpoint:
    https://advsec.dev.azure.com/{org}/_apis/Management/MeterUsage/Last

    Response types handled:
    - 200 OK with usage data       -> Advanced Security is enabled
    - MeterUsageNotFoundException  -> Not enabled or data usage not available
    - HTML/Sign In response        -> Token expired or access denied

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml&pivots=standalone-ghazdo&wt.mc_id=DT-MVP-5005327
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
        $invokeParams = @{
            Uri             = $meterUsageUri
            Method          = 'GET'
            Headers         = $AdoAuthenticationHeader
            UseBasicParsing = $true
        }
        $restResponse = Invoke-RestMethod @invokeParams
    } catch {
        $jsonErrorMessage = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($null -ne $jsonErrorMessage) {
            <#
            Ensure that only the MeterUsageNotFoundException is ignored as this is expected when Advanced Security is
            not enabled
            #>
            if ($jsonErrorMessage.typeKey -ne "MeterUsageNotFoundException") {
                Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
            }
        } else {
            Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    $responseHashTable = @{
        isAdvSecEnabled  = $false
        billingDate      = $null
        isAdvSecBillable = $false
        billedUsers      = @()
    }

    # Check if response content returns a html page which usually indicates token expired
    if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
        Write-Error "Access denied or token expired. Please verify your Bearer token is still valid." -ErrorAction Stop

    } elseif ($null -ne $restResponse) {
        # Advanced Security is enabled, check if usage data is available
        if ($restResponse.isAdvSecEnabled -eq $true) {

            Write-Information -Message "Advanced Security is ENABLED for organization [$Organization]"

            # populate output hash table
            $responseHashTable.isAdvSecEnabled = $restResponse.isAdvSecEnabled
            $responseHashTable.billingDate = $restResponse.billingDate
            $responseHashTable.isAdvSecBillable = $restResponse.isAdvSecBillable
            $responseHashTable.billedUsers = $restResponse.billedUsers

            Write-Output $responseHashTable
        } else {
            Write-Information -Message "Advanced Security is NOT enabled for organization [$Organization]"
        }
    } else {
        Write-Information -Message "Advanced Security is NOT enabled for organization [$Organization]"
    }

    return $responseHashTable
}
