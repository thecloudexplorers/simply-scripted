<#
.SYNOPSIS
    Determines whether Advanced Security is enabled for an Azure DevOps
    organization level.

.DESCRIPTION
    This function queries the Azure DevOps Advanced Security API and detects
    whether Advanced Security is enabled for the organization level. It handles
    three scenarios:
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

    $enablementUri = "https://advsec.dev.azure.com/$Organization/_apis/management/enablement?api-version=7.2-preview.3"

    try {
        # Call the Advanced Security Enablement API
        $invokeParams = @{
            Uri             = $enablementUri
            Method          = 'GET'
            Headers         = $AdoAuthenticationHeader
            UseBasicParsing = $true
        }
        $restResponse = Invoke-RestMethod @invokeParams

        $responseHashTable = @{
            isSecretProtectionPlanEnabled = $false
            isCodeSecurityPlanEnabled     = $false
        }

        # Check if response content returns a html page which usually indicates token expired
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            Write-Error "Access denied or token expired. Please verify your Bearer token is still valid." -ErrorAction Stop

        } elseif ($null -ne $restResponse) {
            Write-Information -Message "Organization level:"

            $secretProtectionPlan = $restResponse.enablementOnCreateSettings.enableSecretProtectionOnCreate
            Write-Information -Message "Advanced Security Secret Protection plan status [$secretProtectionPlan]"

            $codeSecurityPlan = $restResponse.enablementOnCreateSettings.enableCodeSecurityOnCreate
            Write-Information -Message "Advanced Security Code Security plan status [$codeSecurityPlan]"

            # populate output hash table
            $responseHashTable.isSecretProtectionPlanEnabled = $secretProtectionPlan
            $responseHashTable.isCodeSecurityPlanEnabled = $codeSecurityPlan

        } else {
            Write-Information -Message "Advanced Security is NOT enabled for organization [$Organization]"
        }

        return $responseHashTable

    } catch {
        Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
    }
}
