<#
.SYNOPSIS
    Reads Azure DevOps organization-level security and governance policies.

.DESCRIPTION
    Queries the internal Azure DevOps organization policy endpoint to retrieve
    effective values for security, privacy, user, and application connection
    policies. This function provides visibility into organization-level
    governance settings by parsing the internal policy data provider.

.PARAMETER OrganizationName
    The name of your Azure DevOps organization (e.g. 'contoso').

.PARAMETER AdoBearerBasedAuthenticationHeader
    A hashtable containing the Authorization header for the request, e.g.
    @{ Authorization = "Bearer <access-token>" }. This header must be valid and
    have the required permissions to read organization-level settings.

.OUTPUTS
    System.Collections.ArrayList
        A collection of PSCustomObject entries with the following properties:
        - CategoryName        : String - Internal category identifier
        - CategoryDisplayName : String - Human-readable category name
        - Name                : String - Policy identifier
        - DisplayName         : String - Policy description
        - IsEnabled           : Boolean - Effective policy value

.EXAMPLE
    # Create Bearer auth header and call with splatting
    $bearerHeader = @{ Authorization = "Bearer $env:AZDEVOPS_ACCESS_TOKEN" }
    $params = @{
        OrganizationName                   = 'contoso'
        AdoBearerBasedAuthenticationHeader = $bearerHeader
    }
    Read-AdoOrganizationSecurityPolicies @params

.NOTES
    WARNING:
    This function uses an internal and undocumented API endpoint that is not
    part of the officially supported Azure DevOps REST API. Microsoft may change
    or remove this endpoint at any time without notice.

    Endpoints used:
    https://dev.azure.com/{OrganizationName}/_settings/organizationPolicy?__rt=fps&__ver=2

    Authentication:
      - Uses Bearer token authentication via header.

    Version : 0.6.0
    Author  : Jev - @devjevnl | https://www.devjev.nl
    Source  : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines?wt.mc_id=DT-MVP-5005327
#>
function Read-AdoOrganizationSecurityPolicies {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory)]
        [System.String] $OrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoBearerBasedAuthenticationHeader
    )

    # Construct the internal policy settings endpoint
    $organizationPolicyUri = "https://dev.azure.com/$OrganizationName/_settings/organizationPolicy?__rt=fps&__ver=2"


    $invokeParams = @{
        Uri             = $organizationPolicyUri
        Method          = 'GET'
        Headers         = $AdoBearerBasedAuthenticationHeader
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }

    try {
        $restResponse = Invoke-RestMethod @invokeParams

        # Check for HTML content which likely means the token is expired or invalid
        if ($restResponse.Content -match '<html' -or $restResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Navigate to the internal data provider
        $policyData = $restResponse.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'

        # Initialize collection to hold policy objects
        $organizationSecurityPoliciesCollection = [System.Collections.ArrayList]::new()

        # Loop through each policy category (e.g. Security, User, etc.)
        foreach ($categoryName in $policyData.policies.PSObject.Properties.Name) {
            $policiesInCurrentCategory = $policyData.policies.$categoryName

            Write-Information -MessageData "`nProcessing policy category: [$categoryName]"

            $categoryDisplayName = $null
            switch ($categoryName) {
                applicationConnection { $categoryDisplayName = "Application Connection policies" }
                security { $categoryDisplayName = "Security policies" }
                user { $categoryDisplayName = "User policies" }
                privacy { $categoryDisplayName = "Privacy policies" }
                Default { Write-Warning "Unknown policy category detected [$categoryName], check if teh API has been updated!" }
            }


            # Process each policy within the current category
            foreach ($currentPolicy in $policiesInCurrentCategory ) {
                $policyObject = [System.Management.Automation.PSObject]@{
                    CategoryName        = $categoryName
                    CategoryDisplayName = $categoryDisplayName
                    Name                = $currentPolicy.policy.name
                    DisplayName         = $currentPolicy.description
                    IsEnabled           = $currentPolicy.policy.effectiveValue
                }

                Write-Information -MessageData "Processing policy : [$($currentPolicy.description)]"
                [System.Void]$organizationSecurityPoliciesCollection.Add($policyObject)
            }
        }

        # Return the result
        Write-Information -MessageData "All policies have been processed successfully."
        return  $organizationSecurityPoliciesCollection
    } catch {
        Write-Error "Failed to retrieve or parse organization policy data: $($_.Exception.Message)"
    }
}
