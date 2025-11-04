<#
.SYNOPSIS
    Retrieves Azure DevOps organization-level pipelines settings.

.DESCRIPTION
    This function calls the internal Contribution HierarchyQuery endpoint used
    by the Azure DevOps portal to retrieve Azure DevOps Organization pipelines
    settings of categories General, Triggers, and Task restrictions.

.PARAMETER Organization
    The name of your Azure DevOps organization (e.g. 'devjevnl').

.PARAMETER AdoBearerBasedAuthenticationHeader
    A hashtable containing the Authorization header for the request, e.g.
    @{ Authorization = "Bearer <access-token>" }. This header must be valid and
    have the required permissions to read organization-level settings.

.EXAMPLE
    $params = @{
        Organization  = "demojev"
        AdoBearerBasedAuthenticationHeader = $header
    }
    Invoke-AdoPipelineSettingsQuery @params

.NOTES
    WARNING:
    This function uses an internal and undocumented API endpoint that is not
    part of the officially supported Azure DevOps REST API. Microsoft may change
    or remove this endpoint at any time without notice.

    Endpoints used:
    https://dev.azure.com/{org}/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1

    Authentication:
      - Uses Bearer token authentication via header.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Read-AdoOrganizationPipelinesSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String] $OrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoBearerBasedAuthenticationHeader
    )

    # Internal endpoint for querying pipeline settings via contribution data provider
    $contributionHierarchyQueryUri = "https://dev.azure.com/$OrganizationName/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1"

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
        $invokeParams = @{
            Uri             = $contributionHierarchyQueryUri
            Method          = 'POST'
            Headers         = $AdoBearerBasedAuthenticationHeader
            Body            = $body
            UseBasicParsing = $true
        }
        $restResponse = Invoke-RestMethod @invokeParams

        # Token validation: check for HTML content instead of JSON
        if ($restResponse.Content -match '<html' -or $restResponse.RawContent -match 'Sign In') {
            throw "Access denied or token expired. Please verify your Bearer token is still valid."
        }

        # Extract the specific data provider block from the response
        $settings = $restResponse.dataProviders.'ms.vss-build-web.pipelines-org-settings-data-provider'

        # Create structured object for return value
        $settingsObject = [System.Management.Automation.PSObject]@{
            General          = [System.Management.Automation.PSObject]@{
                DisableAnonymousAccessToBadges             = $settings.statusBadgesArePrivate
                LimitVariablesThatCanBeSetAtQueueTime      = $settings.enforceSettableVar
                LimitJobAuthorizationScopeNonRelease       = $settings.enforceJobAuthScope
                LimitJobAuthorizationScopeRelease          = $settings.enforceJobAuthScopeForReleases
                ProtectAccessToRepositoriesInYAMLPipelines = $settings.enforceReferencedRepoScopedToken
                DisableStageChooser                        = $settings.disableStageChooser
                DisableCreationOfClassicBuildPipelines     = $settings.disableClassicBuildPipelineCreation
                DisableCreationOfClassicReleasePipelines   = $settings.disableClassicReleasePipelineCreation
            }
            TaskRestrictions = [System.Management.Automation.PSObject]@{
                DisableBuiltInTasks                 = $settings.disableInBoxTasksVar
                DisableMarketplaceTasks             = $settings.disableMarketplaceTasksVar
                DisableNode6Tasks                   = $settings.disableNode6TasksVar
                EnableShellTasksArgumentsValidation = $settings.enableShellTasksArgsSanitizing
            }
            Triggers         = [System.Management.Automation.PSObject]@{
                LimitPRsFromForksGitHub     = $settings.forkProtectionEnabled
                AllowBuildsFromForks        = $settings.buildsEnabledForForks
                EnforceJobAuthForForks      = $settings.enforceJobAuthScopeForForks
                BlockSecretsAccessFromForks = $settings.enforceNoAccessToSecretsFromForks
                DisableImpliedYAMLCiTrigger = $settings.disableImpliedYAMLCiTrigger
            }
            Diagnostic       = [System.Management.Automation.PSObject]@{
                AuditSettableVariableEnforcement               = $settings.auditEnforceSettableVar
                TaskLockdownFeatureEnabled                     = $settings.isTaskLockdownFeatureEnabled
                HasManagePipelinePoliciesPermission            = $settings.hasManagePipelinePoliciesPermission
                RequireCommentsForPRs                          = $settings.isCommentRequiredForPullRequest
                RequireCommentsNonTeamMembersOnly              = $settings.requireCommentsForNonTeamMembersOnly
                RequireCommentsNonTeamMemberAndNonContributors = $settings.requireCommentsForNonTeamMemberAndNonContributors
                AuditShellArgumentSanitization                 = $settings.enableShellTasksArgsSanitizingAudit
            }
        }

        # Output to console using Write-Information
        Write-Information -MessageData "`nGeneral:"
        Write-Information -MessageData " - Disable anonymous access to badges:                        [$($settingsObject.General.DisableAnonymousAccessToBadges)]"
        Write-Information -MessageData " - Limit variables that can be set at queue time:             [$($settingsObject.General.LimitVariablesThatCanBeSetAtQueueTime)]"
        Write-Information -MessageData " - Limit job authorization (non-release):                     [$($settingsObject.General.LimitJobAuthorizationScopeNonRelease)]"
        Write-Information -MessageData " - Limit job authorization (release):                         [$($settingsObject.General.LimitJobAuthorizationScopeRelease)]"
        Write-Information -MessageData " - Protect access to repositories in YAML pipelines:          [$($settingsObject.General.ProtectAccessToRepositoriesInYAMLPipelines)]"
        Write-Information -MessageData " - Disable stage chooser:                                     [$($settingsObject.General.DisableStageChooser)]"
        Write-Information -MessageData " - Disable creation of classic build pipelines:               [$($settingsObject.General.DisableCreationOfClassicBuildPipelines)]"
        Write-Information -MessageData " - Disable creation of classic release pipelines:             [$($settingsObject.General.DisableCreationOfClassicReleasePipelines)]"

        Write-Information -MessageData "`nTask Restrictions:"
        Write-Information -MessageData " - Disable built-in tasks:                                    [$($settingsObject.TaskRestrictions.DisableBuiltInTasks)]"
        Write-Information -MessageData " - Disable Marketplace tasks:                                 [$($settingsObject.TaskRestrictions.DisableMarketplaceTasks)]"
        Write-Information -MessageData " - Disable Node 6 tasks:                                      [$($settingsObject.TaskRestrictions.DisableNode6Tasks)]"
        Write-Information -MessageData " - Enable shell tasks arguments validation:                   [$($settingsObject.TaskRestrictions.EnableShellTasksArgumentsValidation)]"

        Write-Information -MessageData "`nTriggers:"
        Write-Information -MessageData " - Limit PRs from forks (GitHub):                             [$($settingsObject.Triggers.LimitPRsFromForksGitHub)]"
        Write-Information -MessageData " - Allow builds from forks:                                   [$($settingsObject.Triggers.AllowBuildsFromForks)]"
        Write-Information -MessageData " - Enforce job auth for forks:                                [$($settingsObject.Triggers.EnforceJobAuthForForks)]"
        Write-Information -MessageData " - Block secrets access from forks:                           [$($settingsObject.Triggers.BlockSecretsAccessFromForks)]"
        Write-Information -MessageData " - Disable implied YAML CI trigger:                           [$($settingsObject.Triggers.DisableImpliedYAMLCiTrigger)]"

        Write-Information -MessageData "`nUnmapped / Diagnostic:"
        Write-Information -MessageData " - Audit settable variable enforcement:                       [$($settingsObject.Diagnostic.AuditSettableVariableEnforcement)]"
        Write-Information -MessageData " - Task lockdown feature enabled:                             [$($settingsObject.Diagnostic.TaskLockdownFeatureEnabled)]"
        Write-Information -MessageData " - Has pipeline policies permission:                          [$($settingsObject.Diagnostic.HasManagePipelinePoliciesPermission)]"
        Write-Information -MessageData " - Require comments for PRs:                                  [$($settingsObject.Diagnostic.RequireCommentsForPRs)]"
        Write-Information -MessageData " - Require comments (non-team members):                       [$($settingsObject.Diagnostic.RequireCommentsNonTeamMembersOnly)]"
        Write-Information -MessageData " - Require comments (non-team/non-contributors):              [$($settingsObject.Diagnostic.RequireCommentsNonTeamMemberAndNonContributors)]"
        Write-Information -MessageData " - Audit shell argument sanitization:                         [$($settingsObject.Diagnostic.AuditShellArgumentSanitization)]"

        # Return the settings object
        return $settingsObject
    } catch {
        Write-Error "Failed to retrieve pipeline settings: $($_.Exception.Message)"
    }
}
