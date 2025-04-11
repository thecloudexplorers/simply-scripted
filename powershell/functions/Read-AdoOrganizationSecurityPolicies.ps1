<#
    .SYNOPSIS
    Performs an assessment of Azure DevOps organization-level policies.

    .DESCRIPTION
    This function queries the internal Azure DevOps organization policy endpoint
    and displays effective values for important governance, security, and privacy-related settings.

    .PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'contoso').

    .PARAMETER AccessToken
    A valid Azure DevOps Bearer token with access to read organization-level settings.

    .EXAMPLE
    Invoke-AdoOrgPolicyAssessment -Organization "demojev" -AccessToken $token

    .NOTES
    WARNING: This function uses an internal and undocumented API endpoint:
             https://dev.azure.com/{org}/_settings/organizationPolicy?__rt=fps&__ver=2

             This endpoint is not part of the officially supported Azure DevOps REST API.
             Microsoft may change, deprecate, or remove it at any time without notice.
             Use in production scenarios at your own risk and validate regularly.

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://github.com/PoshCode/PowerShellPracticeAndStyle
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines
#>
function Read-AdoOrganizationSecurityPolicies {
    [CmdletBinding()]
    param (
        # Name of the Azure DevOps organization
        [Parameter(Mandatory)]
        [string]$Organization,

        # Bearer token with permissions to query organization policy settings
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    # Construct the internal policy settings endpoint
    $uri = "https://dev.azure.com/$Organization/_settings/organizationPolicy?__rt=fps&__ver=2"

    # Set headers with Bearer token
    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {
        # Use Invoke-WebRequest to allow content inspection before parsing
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -UseBasicParsing

        # Check for HTML content which likely means the token is expired or invalid
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Convert HTML-safe content into PowerShell object
        $response = $rawResponse.Content | ConvertFrom-Json

        # Navigate to the internal data provider
        $policyData = $response.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'

        Write-Host ""
        Write-Host "===== Azure DevOps Organization Policy Assessment ====="
        Write-Host ""

        # Loop through each policy category (e.g. Security, User, etc.)
        foreach ($categoryName in $policyData.policies.PSObject.Properties.Name) {
            $policies = $policyData.policies.$categoryName

            Write-Host $categoryName.ToUpper()

            # Print each policy’s details
            foreach ($entry in $policies) {
                $p = $entry.policy
                $name = $p.name
                $desc = $entry.description
                $effective = $p.effectiveValue

                Write-Host " - $desc"
                Write-Host "   Name: $name"
                Write-Host "   Effective: $effective"
                Write-Host ""
            }
        }

        Write-Host "Assessment complete."
        Write-Host ""
    } catch {
        Write-Error "Failed to retrieve or parse organization policy data: $($_.Exception.Message)"
    }
}
