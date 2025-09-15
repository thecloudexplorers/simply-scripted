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

        # Check if response content returns a html page which usually indicates token expired
        if ($restResponse.Content -match '<html' -or $restResponse.RawContent -match 'Sign In') {
            Write-Error "Access denied or token expired. Please verify your Bearer token is still valid." -ErrorAction Stop

        } else {
            [System.Object[]]$secretProtectionEnabledRepos = $restResponse.reposEnablementStatus |
            Where-Object { $_.secretProtectionFeatures.secretProtectionEnabled -eq $true }

            # Initialize result collection
            $repoAdvancedSecurityStatusCollection = [System.Collections.ArrayList]::new()

            # Process Secret Protection enabled repositories
            foreach ($currentRepo in $secretProtectionEnabledRepos) {
                $projectId = $currentRepo.projectId
                $repoId = $currentRepo.repositoryId

                # Get project details
                $projectUriTemplate = "https://dev.azure.com/{0}/_apis/projects/{1}?api-version=7.0"
                $projectUri = $projectUriTemplate -f $Organization, $projectId
                $projectInfo = Invoke-RestMethod -Uri $projectUri -Headers $AdoAuthenticationHeader -Method Get

                # Get repository details
                $repoUriTemplate = "https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}?api-version=7.0"
                $repoUri = $repoUriTemplate -f $Organization, $projectId, $repoId

                $repoInfo = Invoke-RestMethod -Uri $repoUri -Headers $AdoAuthenticationHeader -Method Get

                # Add to result collection
                [System.Void]$repoAdvancedSecurityStatusCollection.Add([PSCustomObject]@{
                        ProjectId                 = $projectId
                        ProjectName               = $projectInfo.name
                        RepositoryId              = $repoId
                        RepositoryName            = $repoInfo.name
                        SecretProtectionEnabled   = $true
                        DependencyScanningEnabled = $false
                        CodeSecurityEnabled       = $false
                    })
            }

            [System.Object[]]$codeSecurityEnabledRepos = $restResponse.reposEnablementStatus |
            Where-Object { $_.codeSecurityFeatures.codeSecurityEnabled -eq $true }

            # Process Code Security enabled repositories
            foreach ($currentRepo in $codeSecurityEnabledRepos) {
                $projectId = $currentRepo.projectId
                $repoId = $currentRepo.repositoryId

                # Check if this repository is already in our results (has secretProtectionEnabledRepos enabled)
                $existingRepo = $repoAdvancedSecurityStatusCollection | Where-Object { $_.RepositoryId -eq $repoId }

                if ($existingRepo) {
                    # Update existing entry
                    $existingRepo.CodeSecurityEnabled = $currentRepo.codeSecurityFeatures.codeSecurityEnabled
                    $existingRepo.DependencyScanningEnabled = $currentRepo.codeSecurityFeatures.dependencyScanningInjectionEnabled

                } else {
                    # Get project details
                    $projectUriTemplate = "https://dev.azure.com/{0}/_apis/projects/{1}?api-version=7.0"
                    $projectUri = $projectUriTemplate -f $Organization, $projectId
                    $projectInfo = Invoke-RestMethod -Uri $projectUri -Headers $AdoAuthenticationHeader -Method Get

                    # Get repository details
                    $repoUriTemplate = "https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}?api-version=7.0"
                    $repoUri = $repoUriTemplate -f $Organization, $projectId, $repoId
                    $repoInfo = Invoke-RestMethod -Uri $repoUri -Headers $AdoAuthenticationHeader -Method Get

                    # Add new entry
                    [System.Void]$repoAdvancedSecurityStatusCollection.Add([PSCustomObject]@{
                            ProjectId                 = $projectId
                            ProjectName               = $projectInfo.name
                            RepositoryId              = $repoId
                            RepositoryName            = $repoInfo.name
                            SecretProtectionEnabled   = $false
                            CodeSecurityEnabled       = $currentRepo.codeSecurityFeatures.codeSecurityEnabled
                            DependencyScanningEnabled = $currentRepo.codeSecurityFeatures.dependencyScanningInjectionEnabled
                        })
                }
            }

            # Summary output
            $reposWithSecretProtection = $repoAdvancedSecurityStatusCollection | Where-Object { $_.SecretProtectionEnabled -eq $true }
            $reposWithCodeSecurity = $repoAdvancedSecurityStatusCollection | Where-Object { $_.CodeSecurityEnabled -eq $true }
            Write-Information -Message "Total repositories with Secret Protection enabled: [$($reposWithSecretProtection.Count)]"
            Write-Information -Message "Total repositories with Code Security enabled: [$($reposWithCodeSecurity.Count)]"

            # Return the result
            return  $repoAdvancedSecurityStatusCollection

            Write-Host "Stopped here!!!"
        }
    } catch {
        Write-Error "Unexpected error occurred: $($_.Exception.Message)" -ErrorAction Stop
    }
}
