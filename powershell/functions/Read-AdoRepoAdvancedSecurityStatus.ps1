<#
.SYNOPSIS
    Reads repository-level Advanced Security status for all repos in an
    Azure DevOps organization.

.DESCRIPTION
    Queries the Azure DevOps Advanced Security organization status endpoint
    to enumerate each repository's Advanced Security features. For every
    repository, returns whether:
      - Secret Protection is enabled and related metadata (last changed date,
        changed by, block pushes)
      - Code Security is enabled and related metadata (last changed date,
        changed by, dependency scanning)

    The function also expands project and repository names for convenience by
    calling the Core and Git APIs.

.PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'devjevnl').

.PARAMETER AdoAuthenticationHeader
    A hashtable containing the Azure DevOps authentication headers for PAT
    usage. Should include 'Content-Type' and 'Authorization' keys, e.g.:
        $patAuthenticationHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Basic ' + $adoAuthToken
        }

.OUTPUTS
    System.Object[]
        An array of PSCustomObject entries with the following shape:
        - ProjectId, ProjectName, RepositoryId, RepositoryName
        - SecretProtectionFeatures: {
            SecretProtectionEnabled,
            SecretProtectionEnablementLastChangedDate,
            SecretProtectionChangedBy,
            BlockPushes
          }
        - CodeSecurityFeatures: {
            CodeSecurityEnabled,
            CodeSecurityLastChangedDate,
            CodeSecurityChangedBy,
            DependencyScanningInjectionEnabled
          }

.EXAMPLE
    # Create PAT-based auth header and call with splatting
    $adoAuthTokenParams = @{
        PatToken          = $patTokenReadAdvancedSecurity
        PatTokenOwnerName = $PatTokenOwnerName
    }
    $adoAuthToken = New-AdoAuthenticationToken @adoAuthTokenParams

    $patAuthenticationHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $adoAuthToken
    }

    $params = @{
        Organization            = 'devjevnl'
        AdoAuthenticationHeader = $patAuthenticationHeader
    }
    Read-AdoRepoAdvancedSecurityStatus @params

.NOTES
    Endpoints used:
      - Enablement (org):
        https://advsec.dev.azure.com/{organization}/_apis/management/enablement?
        includeAllProperties=true&api-version=7.2-preview.3
      - Project details:
        https://dev.azure.com/{organization}/_apis/projects/{projectId}?api-version=7.0
      - Repository details:
        https://dev.azure.com/{organization}/{projectId}/_apis/git/repositories/{repoId}?api-version=7.0

    Authentication:
      - Uses PAT via Basic Authorization header

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/advancedsecurity/org-enablement/get
#>
function Read-AdoRepoAdvancedSecurityStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    # Get the current status of Advanced Security for the organization
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/advancedsecurity/org-enablement/get
    # ?view=azure-devops-rest-7.2&wt.mc_id=DT-MVP-5005327
    # GET https://advsec.dev.azure.com/{organization}/_apis/management/enablement?api-version=7.2-preview.3
    $baseUri = "https://advsec.dev.azure.com/$Organization/_apis/management/enablement"
    $enablementUri = "$baseUri?includeAllProperties=true&api-version=7.2-preview.3"

    try {

        # Call the Advanced Security Enablement API
        $invokeParams = @{
            Uri             = $enablementUri
            Method          = 'GET'
            Headers         = $AdoAuthenticationHeader
            UseBasicParsing = $true
        }
        $restResponse = Invoke-RestMethod @invokeParams

        # Check if response content returns a html page which usually indicates token expired
        if ($restResponse.Content -match '<html' -or $restResponse.RawContent -match 'Sign In') {
            $errorMessage = "Access denied or token expired. Please verify your Bearer token is still valid."
            Write-Error $errorMessage -ErrorAction Stop

        } else {
            [System.Collections.ArrayList]$secretProtectionEnabledRepos = $restResponse.reposEnablementStatus

            # Initialize result collection
            $repoAdvancedSecurityStatusCollection = [System.Collections.ArrayList]::new()

            # Process Secret Protection enabled repositories
            foreach ($currentRepo in $secretProtectionEnabledRepos) {
                $projectId = $currentRepo.projectId
                $repoId = $currentRepo.repositoryId

                # Get project details
                $projectUriTemplate = "https://dev.azure.com/{0}/_apis/projects/{1}?api-version=7.0"
                $projectUri = $projectUriTemplate -f $Organization, $projectId
                $projectInfo = Invoke-RestMethod -Uri $projectUri -Headers $AdoAuthenticationHeader -Method 'GET'

                # Get repository details
                $repoUriTemplate = "https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}?api-version=7.0"
                $repoUri = $repoUriTemplate -f $Organization, $projectId, $repoId

                $repoInfo = Invoke-RestMethod -Uri $repoUri -Headers $AdoAuthenticationHeader -Method 'GET'

                # Get Secret Protection Changed By Display Name
                $secretProtectionChangedByDisplayName = $null
                $secretProtectionChangedBy = $currentRepo.secretProtectionFeatures.secretProtectionChangedBy
                if ($secretProtectionChangedBy -ne "00000000-0000-0000-0000-000000000000") {
                    $identityBaseUri = "https://vssps.dev.azure.com/{0}/_apis/identities/{1}"
                    $identityApiVersion = "api-version=7.2-preview.1"
                    $identityUriTemplate = "$identityBaseUri?$identityApiVersion"
                    $identityUri = $identityUriTemplate -f $Organization, $secretProtectionChangedBy

                    $identityInfo = Invoke-RestMethod -Uri $identityUri -Headers $AdoAuthenticationHeader -Method 'GET'
                    $secretProtectionChangedByDisplayName = $identityInfo.providerDisplayName
                }

                # Get Code Security Changed By Display Name
                $codeSecurityChangedByDisplayName = $null
                $codeSecurityChangedBy = $currentRepo.codeSecurityFeatures.codeSecurityChangedBy
                if ($codeSecurityChangedBy -ne "00000000-0000-0000-0000-000000000000") {
                    $identityBaseUri = "https://vssps.dev.azure.com/{0}/_apis/identities/{1}"
                    $identityApiVersion = "api-version=7.2-preview.1"
                    $identityUriTemplate = "$identityBaseUri?$identityApiVersion"
                    $identityUri = $identityUriTemplate -f $Organization, $codeSecurityChangedBy

                    $identityInfo = Invoke-RestMethod -Uri $identityUri -Headers $AdoAuthenticationHeader -Method 'GET'
                    $codeSecurityChangedByDisplayName = $identityInfo.providerDisplayName
                }

                # Add to result collection
                $secretFeatures = $currentRepo.secretProtectionFeatures
                $codeFeatures = $currentRepo.codeSecurityFeatures
                
                [System.Void]$repoAdvancedSecurityStatusCollection.Add([PSCustomObject]@{
                        ProjectId                = $projectId
                        ProjectName              = $projectInfo.name
                        RepositoryId             = $repoId
                        RepositoryName           = $repoInfo.name
                        SecretProtectionFeatures = [PSCustomObject]@{
                            SecretProtectionEnabled         = $secretFeatures.secretProtectionEnabled
                            SecretProtectionEnablementLastChangedDate = `
                                $secretFeatures.secretProtectionEnablementLastChangedDate
                            SecretProtectionChangedBy       = $secretProtectionChangedByDisplayName
                            BlockPushes                     = $secretFeatures.blockPushes
                        }
                        CodeSecurityFeatures     = [PSCustomObject]@{
                            CodeSecurityEnabled                = $codeFeatures.codeSecurityEnabled
                            CodeSecurityLastChangedDate        = $codeFeatures.codeSecurityLastChangedDate
                            CodeSecurityChangedBy              = $codeSecurityChangedByDisplayName
                            DependencyScanningInjectionEnabled = $codeFeatures.dependencyScanningInjectionEnabled
                        }
                    })
            }

            # Summary output
            $totalRepos = $repoAdvancedSecurityStatusCollection.Count
            $secretProtectionFilter = { $_.SecretProtectionFeatures.SecretProtectionEnabled -eq $false }
            $codeSecurityFilter = { $_.CodeSecurityFeatures.CodeSecurityEnabled -eq $false }
            
            $reposWithOutSecretProtection = $repoAdvancedSecurityStatusCollection | Where-Object $secretProtectionFilter
            $reposWithOutCodeSecurity = $repoAdvancedSecurityStatusCollection | Where-Object $codeSecurityFilter
            
            Write-Information -Message "Repositories that have Secret Protection disabled:"
            Write-Information -Message "[$($reposWithOutSecretProtection.Count) out of $totalRepos]"
            Write-Information -Message ""
            
            Write-Information -Message "Repositories that have Code Security disabled:"
            Write-Information -Message "[$($reposWithOutCodeSecurity.Count) out of $totalRepos]"

            # Return the result
            return  $repoAdvancedSecurityStatusCollection
        }
    } catch {
        Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
    }
}
