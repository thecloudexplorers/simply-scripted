<#
.SYNOPSIS
    Reads organization-level Advanced Security enablement settings in Azure
    DevOps.

.DESCRIPTION
    Uses the Azure DevOps Advanced Security enablement endpoint to determine
    whether the following organization-level plans are enabled:
    - Secret Protection
    - Code Security

    Returns a hashtable with:
    - isSecretProtectionPlanEnabled (bool)
    - isCodeSecurityPlanEnabled     (bool)

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
    This function queries the Azure DevOps Advanced Security organization
    enablement endpoint to read the default plan enablement settings:

    Endpoint:
    https://advsec.dev.azure.com/{organization}/_apis/management/enablement?api-version=7.2-preview.3

    Determines organization-level defaults for:
    - Secret Protection (enableSecretProtectionOnCreate)
    - Code Security     (enableCodeSecurityOnCreate)

    Authentication:
    - Uses PAT via Basic Authorization header

    Version     : 2.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml&pivots=standalone-ghazdo&wt.mc_id=DT-MVP-5005327
#>
function Read-AdoOrganizationAdvancedSecurityStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    # Get the current status of Advanced Security for the organization
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/advancedsecurity/org-enablement/get?view=azure-devops-rest-7.2&wt.mc_id=DT-MVP-5005327
    # GET https://advsec.dev.azure.com/{organization}/_apis/management/enablement?api-version=7.2-preview.3
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

            # Populate output hash table
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
