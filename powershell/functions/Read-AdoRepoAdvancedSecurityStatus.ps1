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
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/advancedsecurity/org-enablement/get?view=azure-devops-rest-7.2&wt.mc_id=DT-MVP-5005327
    # GET https://advsec.dev.azure.com/{organization}/_apis/management/enablement?api-version=7.2-preview.3
    $enablementUri = "https://advsec.dev.azure.com/$Organization/_apis/management/enablement?includeAllProperties=true&api-version=7.2-preview.3"

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
            Write-Error "Access denied or token expired. Please verify your Bearer token is still valid." -ErrorAction Stop

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
                if ($currentRepo.secretProtectionFeatures.secretProtectionChangedBy -ne "00000000-0000-0000-0000-000000000000") {
                    $identityUriTemplate = "https://vssps.dev.azure.com/{0}/_apis/identities/{1}?api-version=7.2-preview.1"
                    $identityUri = $identityUriTemplate -f $Organization, $currentRepo.secretProtectionFeatures.secretProtectionChangedBy

                    $identityInfo = Invoke-RestMethod -Uri $identityUri -Headers $AdoAuthenticationHeader -Method 'GET'
                    $secretProtectionChangedByDisplayName = $identityInfo.providerDisplayName
                }

                # Get Code Security Changed By Display Name
                $codeSecurityChangedByDisplayName = $null
                if ($currentRepo.codeSecurityFeatures.codeSecurityChangedBy -ne "00000000-0000-0000-0000-000000000000") {
                    $identityUriTemplate = "https://vssps.dev.azure.com/{0}/_apis/identities/{1}?api-version=7.2-preview.1"
                    $identityUri = $identityUriTemplate -f $Organization, $currentRepo.codeSecurityFeatures.codeSecurityChangedBy

                    $identityInfo = Invoke-RestMethod -Uri $identityUri -Headers $AdoAuthenticationHeader -Method 'GET'
                    $codeSecurityChangedByDisplayName = $identityInfo.providerDisplayName
                }

                # Add to result collection
                [System.Void]$repoAdvancedSecurityStatusCollection.Add([PSCustomObject]@{
                        ProjectId                = $projectId
                        ProjectName              = $projectInfo.name
                        RepositoryId             = $repoId
                        RepositoryName           = $repoInfo.name
                        SecretProtectionFeatures = [PSCustomObject]@{
                            SecretProtectionEnabled                   = $currentRepo.secretProtectionFeatures.secretProtectionEnabled
                            SecretProtectionEnablementLastChangedDate = $currentRepo.secretProtectionFeatures.secretProtectionEnablementLastChangedDate
                            SecretProtectionChangedBy                 = $secretProtectionChangedByDisplayName
                            BlockPushes                               = $currentRepo.secretProtectionFeatures.blockPushes
                        }
                        CodeSecurityFeatures     = [PSCustomObject]@{
                            CodeSecurityEnabled                = $currentRepo.codeSecurityFeatures.codeSecurityEnabled
                            CodeSecurityLastChangedDate        = $currentRepo.codeSecurityFeatures.codeSecurityLastChangedDate
                            CodeSecurityChangedBy              = $codeSecurityChangedByDisplayName
                            DependencyScanningInjectionEnabled = $currentRepo.codeSecurityFeatures.dependencyScanningInjectionEnabled
                        }
                    })
            }

            # Summary output
            $reposWithOutSecretProtection = $repoAdvancedSecurityStatusCollection | Where-Object { $_.SecretProtectionFeatures.SecretProtectionEnabled -eq $false }
            $reposWithOutCodeSecurity = $repoAdvancedSecurityStatusCollection | Where-Object { $_.CodeSecurityFeatures.CodeSecurityEnabled -eq $false }
            Write-Information -Message "Repositories that have Secret Protection disabled:"
            Write-Information -Message "[$($reposWithOutSecretProtection.Count) out of $($repoAdvancedSecurityStatusCollection.Count)]"

            Write-Information -Message "Repositories that have Code Security disabled: "
            Write-Information -Message "[$($reposWithOutCodeSecurity.Count) out of $($repoAdvancedSecurityStatusCollection.Count)]"

            # Return the result
            return  $repoAdvancedSecurityStatusCollection
        }
    } catch {
        Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
    }
}
