#Requires -PSEdition Core
<#
    .SYNOPSIS
    Creates an Azure DevOps Minimum Number Of Reviewers branch policy configuration.

    .DESCRIPTION
    Creates a Minimum Number Of Reviewers branch policy on a specific branch
    in an Azure DevOps Git repository.

    The function builds the policy configuration payload, scopes it to the
    supplied repository and branch reference, sets the policy as enabled and
    blocking, and then submits the configuration to the Azure DevOps Policy
    Configurations REST API.

    Because the function supports ShouldProcess, you can use -WhatIf and
    -Confirm to preview or control the REST API call.

    .PARAMETER AdoAuthenticationHeader
    A hashtable containing the Azure DevOps authentication headers used for
    the REST API call. The header should include values such as Content-Type
    and Authorization.

    .PARAMETER AdoOrganizationName
    The name of the target Azure DevOps organization.

    .PARAMETER AdoProjectName
    The name or id of the target Azure DevOps project.

    .PARAMETER AdoRepositoryId
    The id of the target Azure DevOps Git repository.

    .PARAMETER PolicyId
    The policy type id for the Minimum Number Of Reviewers policy definition.

    .PARAMETER BranchPathReference
    The fully qualified Git ref for the target branch, for example
    refs/heads/main.

    .OUTPUTS
    System.Object
    Returns the Azure DevOps policy configuration object created by the REST
    API when the request succeeds.

    .EXAMPLE
    $adoAuthHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $adoAuthToken
    }

    $minimumNumberOfReviewersArgs = @{
        AdoAuthenticationHeader = $adoAuthHeader
        AdoOrganizationName     = 'contoso'
        PolicyId                = $gitBranchPolicyDefinition.MinimumNumberOfReviewers
        AdoProjectName          = 'platform-engineering'
        AdoRepositoryId         = $lzConfigRepo.Id
        BranchPathReference     = 'refs/heads/main'
    }

    Set-AdoGitMinimumNumberOfReviewersBranchPolicy @minimumNumberOfReviewersArgs

    Creates a blocking Minimum Number Of Reviewers policy on the main branch
    for the supplied repository.

    .EXAMPLE
    Set-AdoGitMinimumNumberOfReviewersBranchPolicy @minimumNumberOfReviewersArgs -WhatIf

    Shows what would be submitted to the Azure DevOps Policy Configurations
    endpoint without creating the policy.

    .NOTES
    Endpoint:
    POST https://dev.azure.com/{organization}/{project}/_apis/policy/configurations?api-version=7.1-preview.1

    Notes:
    - The created policy is enabled and blocking.
    - The minimum approver count is set to 1.
    - The policy scope is limited to the exact branch reference provided.
    - The function creates a new policy configuration; it does not update an
      existing one.

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/policy/configurations/create?view=azure-devops-rest-7.1&tabs=HTTP

#>

function Set-AdoGitMinimumNumberOfReviewersBranchPolicy {
    [CmdLetBinding(SupportsShouldProcess)]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoRepositoryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $PolicyId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $BranchPathReference
    )

    $policyConfigurationObject = @{
        type       = @{
            id = $PolicyId
        }
        revision   = "1"
        isEnabled  = $true
        isBlocking = $true
        isDeleted  = $false
        settings   = @{
            allowDownvotes              = $false
            blockLastPusherVote         = $true
            creatorVoteCounts           = $false
            requireVoteOnLastIteration  = $false
            resetOnSourcePush           = $true
            resetRejectionsOnSourcePush = $false
            minimumApproverCount        = "1"
            scope                       = @(
                @{
                    repositoryId = $AdoRepositoryId
                    refName      = $BranchPathReference
                    matchKind    = "Exact"
                }
            )
        }
    }

    $policyConfigurationJsonObject = $policyConfigurationObject | ConvertTo-Json -Depth 10

    # create a Minimum Number Of Reviewers policy on the concerning branch
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/policy/configurations/create?view=azure-devops-rest-7.0&tabs=HTTP
    # POST https://dev.azure.com/{organization}/{project}/_apis/policy/configurations/{configurationId}?api-version=7.0
    $policyConfigurationUri = "https://dev.azure.com/$AdoOrganizationName/$AdoProjectName/_apis/policy/configurations?api-version=7.1-preview.1"
    if ($PSCmdlet.ShouldProcess("$policyConfigurationUri", "Invoke-RestMethod")) {
        $policyConfigurationResponse = Invoke-RestMethod -Method 'POST' -Uri $policyConfigurationUri -Headers $AdoAuthenticationHeader -Body $policyConfigurationJsonObject

        return $policyConfigurationResponse
    }
}
