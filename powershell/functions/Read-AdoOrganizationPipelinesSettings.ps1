<#
    .SYNOPSIS
    Retrieves Azure DevOps organization-level pipeline settings.

    .DESCRIPTION
    This function calls the internal Contribution HierarchyQuery endpoint used by the Azure DevOps portal
    to retrieve pipeline security, policy, and control settings for the entire organization.

    .PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'contoso').

    .PARAMETER AccessToken
    A valid Azure DevOps Bearer token with access to organization settings.

    .EXAMPLE
    Invoke-AdoPipelineSettingsQuery -Organization "demojev" -AccessToken $token

    .NOTES
    WARNING: This function uses an internal and undocumented API endpoint:
             https://dev.azure.com/{org}/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1

             Microsoft may change or remove this endpoint without notice.

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines
#>
function Read-AdoOrganizationPipelinesSettings {
    [CmdletBinding()]
    param (
        # Azure DevOps organization name
        [Parameter(Mandatory = $true)]
        [string]$Organization,

        # Bearer token for authentication
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    # Internal endpoint for querying pipeline settings via contribution data provider
    $uri = "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1"

    # Auth and content headers
    $headers = @{
        Authorization  = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    <#
    Request body to simulate portal request.
    Note: this request is a POST but it does not contain properties to change, this is a workaround to getting the
    settings as the GET method is not supported.
    #>
    $body = @(
        @{
            contributionIds     = @("ms.vss-build-web.pipelines-org-settings-data-provider")
            dataProviderContext = @{
                properties = @{
                    sourcePage = @{
                        url         = "https://dev.azure.com/$Organization/_settings/pipelinessettings"
                        routeId     = "ms.vss-admin-web.collection-admin-hub-route"
                        routeValues = @{
                            adminPivot  = "pipelinessettings"
                            controller  = "ContributedPage"
                            action      = "Execute"
                            serviceHost = "00000000-0000-0000-0000-000000000000 ($Organization)"
                        }
                    }
                }
            }
        }
    ) | ConvertTo-Json -Depth 10

    try {
        # Get raw response so we can detect HTML fallback (expired token, etc.)
        $rawResponse = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $body -UseBasicParsing

        # Token validation: check for HTML content instead of JSON
        if ($rawResponse.Content -match '<html' -or $rawResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Convert and parse JSON content safely
        $response = $rawResponse.Content | ConvertFrom-Json

        # Extract the specific data provider block from the response
        $settings = $response.dataProviders.'ms.vss-build-web.pipelines-org-settings-data-provider'

        Write-Host ""
        Write-Host "===== Azure DevOps Pipeline Settings Assessment ====="
        Write-Host ""

        # Grouped, labeled, readable output
        Write-Host "General:"
        Write-Host " - Disable anonymous access to badges:                        $($settings.statusBadgesArePrivate)"
        Write-Host " - Limit variables that can be set at queue time:             $($settings.enforceSettableVar)"
        Write-Host " - Limit job authorization (non-release):                     $($settings.enforceJobAuthScope)"
        Write-Host " - Limit job authorization (release):                         $($settings.enforceJobAuthScopeForReleases)"
        Write-Host " - Protect access to repositories in YAML pipelines:          $($settings.enforceReferencedRepoScopedToken)"
        Write-Host " - Disable stage chooser:                                     $($settings.disableStageChooser)"
        Write-Host " - Disable creation of classic build pipelines:               $($settings.disableClassicBuildPipelineCreation)"
        Write-Host " - Disable creation of classic release pipelines:             $($settings.disableClassicReleasePipelineCreation)"

        Write-Host "`nTask Restrictions:"
        Write-Host " - Disable built-in tasks:                                    $($settings.disableInBoxTasksVar)"
        Write-Host " - Disable Marketplace tasks:                                 $($settings.disableMarketplaceTasksVar)"
        Write-Host " - Disable Node 6 tasks:                                      $($settings.disableNode6TasksVar)"
        Write-Host " - Enable shell tasks arguments validation:                   $($settings.enableShellTasksArgsSanitizing)"

        Write-Host "`nTriggers:"
        Write-Host " - Limit PRs from forks (GitHub):                             $($settings.forkProtectionEnabled)"
        Write-Host " - Allow builds from forks:                                   $($settings.buildsEnabledForForks)"
        Write-Host " - Enforce job auth for forks:                                $($settings.enforceJobAuthScopeForForks)"
        Write-Host " - Block secrets access from forks:                           $($settings.enforceNoAccessToSecretsFromForks)"
        Write-Host " - Disable implied YAML CI trigger:                           $($settings.disableImpliedYAMLCiTrigger)"

        Write-Host "`nUnmapped / Diagnostic:"
        Write-Host " - Audit settable variable enforcement:                       $($settings.auditEnforceSettableVar)"
        Write-Host " - Task lockdown feature enabled:                             $($settings.isTaskLockdownFeatureEnabled)"
        Write-Host " - Has pipeline policies permission:                          $($settings.hasManagePipelinePoliciesPermission)"
        Write-Host " - Require comments for PRs:                                  $($settings.isCommentRequiredForPullRequest)"
        Write-Host " - Require comments (non-team members):                       $($settings.requireCommentsForNonTeamMembersOnly)"
        Write-Host " - Require comments (non-team/non-contributors):              $($settings.requireCommentsForNonTeamMemberAndNonContributors)"
        Write-Host " - Audit shell argument sanitization:                         $($settings.enableShellTasksArgsSanitizingAudit)"


        Write-Host ""
        Write-Host "Assessment complete."
    } catch {
        Write-Error "Failed to retrieve pipeline settings: $($_.Exception.Message)"
    }
}
