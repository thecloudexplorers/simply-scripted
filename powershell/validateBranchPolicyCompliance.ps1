<#
    .SYNOPSIS
    Validates a pull request's branch name, target branch, and freshness.

    .DESCRIPTION
    Checks the source branch against the naming rules and allowed target rules in
    branchPolicy.config.jsonc. It also verifies lowercase naming and compares the
    source branch with the target to report ahead/behind commit counts.

    When run by Azure Pipelines (TF_BUILD is set), the configured Git remote is fetched
    for the freshness check and a Markdown build summary is published.

    When run locally, freshness is checked only when both corresponding local branch or
    remote-tracking refs are available; otherwise that check is reported as skipped.

    .PARAMETER SourceBranch
    Source branch to validate, e.g. the pipeline's System.PullRequest.SourceBranch.
    Accepts a branch name or a refs/heads/... ref.

    .PARAMETER TargetBranch
    Target branch of the pull request, e.g. the pipeline's System.PullRequest.TargetBranch.
    Accepts a branch name or a refs/heads/... ref.

    .PARAMETER RootRepoLocation
    The root repository location. Used to resolve the config file and companion script paths.

    .EXAMPLE
    $validateBranchPolicyParameters = @{
        RootRepoLocation = '.'
        SourceBranch = 'feature/devjev/3936-azure-devops-project-stamping'
        TargetBranch = 'develop'
    }
    ./validateBranchPolicy.ps1 @validateBranchPolicyParameters

    Validates the branch name and configured PR destination locally. If both refs
    exist in the current repository, also checks freshness and reports ahead and
    behind counts.

    .EXAMPLE
    $validateBranchPolicyParameters = @{
        RootRepoLocation = '.'
        SourceBranch = 'refs/heads/hotfix/devjev/4202-fix-project-creation'
        TargetBranch = 'refs/heads/main'
    }
    ./validateBranchPolicy.ps1 @validateBranchPolicyParameters

    Validates fully qualified branch refs.

    .EXAMPLE
    $validateBranchPolicyParameters = @{
        RootRepoLocation = "$(Pipeline.Workspace)/s"
        SourceBranch = "$(System.PullRequest.SourceBranch)"
        TargetBranch = "$(System.PullRequest.TargetBranch)"
    }
    ./validateBranchPolicy.ps1 @validateBranchPolicyParameters

    Pipeline step for PR build validation; fetches both branches and publishes a build summary.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    The JSONC configuration controls allowed branch types, branch segment patterns,
    Git remote, and per-type target rules. Set an allowedTargets value to ["*"]
    to allow any target for that branch type.

    The script exits with code 1 when local validation finds any failure. In Azure
    Pipelines, failures are reported through task logging commands.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $RootRepoLocation,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $SourceBranch,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $TargetBranch
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path -Path $RootRepoLocation -ChildPath 'branchPolicy.config.jsonc'

# Load ConvertFrom-Jsonc function via dot sourcing
$convertFromJsonc = Join-Path -Path $RootRepoLocation -ChildPath 'ConvertFrom-Jsonc.ps1'
. $convertFromJsonc

# $failures drives the final result, $checkResults feeds the summary and log output
$failures = [System.Collections.Generic.List[System.String]]::new()
$checkResults = [System.Collections.Generic.List[System.Object]]::new()
$aheadBehind = [System.String] 'Not checked'
$isAzurePipeline = -not [System.String]::IsNullOrWhiteSpace($env:TF_BUILD)
$localMode = -not $isAzurePipeline

# Load and validate the branch policy configuration
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Branch policy configuration '$configPath' was not found."
}
try {
    $configContent = Get-Content -LiteralPath $configPath -Raw
    $config = ConvertFrom-Jsonc -JsoncContent $configContent
} catch {
    throw "Could not read branch policy JSONC '$configPath': $_"
}

$remoteName = [System.String] $config.gitRemote
$branchNaming = $config.branchNaming
$allowedTypes = @($branchNaming.allowedTypes | ForEach-Object { [System.String] $_ })
$allowedTargets = $config.allowedTargets

if ([System.String]::IsNullOrWhiteSpace($remoteName) -or $allowedTypes.Count -eq 0) {
    throw 'Configuration must define gitRemote and at least one branchNaming.allowedTypes entry.'
}

foreach ($type in $allowedTypes) {
    if ($null -eq $allowedTargets.PSObject.Properties[$type]) {
        throw "Configuration must define allowedTargets.[$type] (use '*' to allow any target)."
    }
}

# Compile the naming patterns up front so an invalid pattern fails fast
try {
    $userTagRegex = [System.Text.RegularExpressions.Regex]::new([System.String] $branchNaming.userTagPattern)
    $workItemIdRegex = [System.Text.RegularExpressions.Regex]::new([System.String] $branchNaming.workItemIdPattern)
    $descriptionRegex = [System.Text.RegularExpressions.Regex]::new([System.String] $branchNaming.descriptionPattern)
} catch {
    throw "A branch naming regular expression in '$configPath' is invalid: $_"
}
$branchFormat = [System.String] $branchNaming.format

# Accept both 'name' and 'refs/heads/name' input
$SourceBranch = $SourceBranch -replace '^refs/heads/', ''
$TargetBranch = $TargetBranch -replace '^refs/heads/', ''

Write-Host "Source branch : [$SourceBranch]"
Write-Host "Target branch : [$TargetBranch]"
Write-Host "Validation mode: [$(if ($localMode) { 'Local' } else { 'Pull request' })]"

# Check 1: branch naming, collecting every issue instead of stopping at the first
$segments = $SourceBranch.Split('/')
$namingIssues = [System.Collections.Generic.List[System.String]]::new()
$branchType = if ($segments.Count -gt 0) { $segments[0] } else { '' }

if ($segments.Count -ne 3) {
    $namingIssues.Add("Expected 3 slash-separated segments but found [$($segments.Count)].")
}

if (-not ($allowedTypes -ccontains $branchType)) {
    # -ccontains: branch types are case-sensitive
    $namingIssues.Add("Type [$branchType] is not allowed; use: $($allowedTypes -join ', ').")
}

if ($segments.Count -gt 1 -and -not $userTagRegex.IsMatch($segments[1])) {
    $namingIssues.Add("User tag [$($segments[1])] must match [$($branchNaming.userTagPattern)].")
}

if ($segments.Count -gt 2) {
    # Split on the first hyphen only, the description may contain more hyphens
    $workItemParts = $segments[2] -split '-', 2
    if ($workItemParts.Count -ne 2 -or [System.String]::IsNullOrWhiteSpace($workItemParts[1])) {
        $namingIssues.Add('Work-item segment must contain an ID, hyphen, and non-empty description.')
    } else {
        if (-not $workItemIdRegex.IsMatch($workItemParts[0])) {
            $namingIssues.Add("Work-item ID [$($workItemParts[0])] must match [$($branchNaming.workItemIdPattern)].")
        }
        if (-not $descriptionRegex.IsMatch($workItemParts[1])) {
            $namingIssues.Add("Description [$($workItemParts[1])] must match [$($branchNaming.descriptionPattern)].")
        }
    }
}

$branchNameValid = $namingIssues.Count -eq 0
if ($branchNameValid) {
    $checkResult = [pscustomobject]@{
        Check    = 'Branch naming'
        Status   = 'Passed'
        Details  = "Branch matches '$branchFormat'."
        NextStep = 'No action needed.'
    }
    $checkResults.Add($checkResult)
} else {
    foreach ($namingIssue in $namingIssues) {
        $failures.Add("Branch '$SourceBranch': $namingIssue")
    }

    $exampleType = $allowedTypes[0]

    $checkResult = [pscustomobject]@{
        Check    = 'Branch naming'
        Status   = 'Failed'
        Details  = $namingIssues -join ' '
        NextStep = "Rename it to '$branchFormat' (example: '$exampleType/devjev/3936-azure-devops-project-stamping')."
    }
    $checkResults.Add($checkResult)
}

# Check 2: lowercase naming, case-sensitive comparison
if ($SourceBranch -ceq $SourceBranch.ToLowerInvariant()) {
    $checkResult = [pscustomobject]@{
        Check    = 'Lowercase naming'
        Status   = 'Passed'
        Details  = 'Branch name contains no uppercase letters.'
        NextStep = 'No action needed.'
    }
    $checkResults.Add($checkResult)
} else {
    $lowercaseError = "Branch '$SourceBranch' must be all lowercase."
    $failures.Add($lowercaseError)

    $checkResult = [pscustomobject]@{
        Check    = 'Lowercase naming'
        Status   = 'Failed'
        Details  = $lowercaseError
        NextStep = "Rename it using lowercase letters, for example '$($SourceBranch.ToLowerInvariant())'."
    }
    $checkResults.Add($checkResult)
}

# Check 3: allowed target, skipped when the branch type has no configured rule
if (-not ($allowedTypes -ccontains $branchType)) {
    $checkResult = [pscustomobject]@{
        Check    = 'Allowed target'
        Status   = 'Skipped'
        Details  = "No target rule applies to unrecognized branch type '$branchType'."
        NextStep = 'Use a configured branch type.'
    }
    $checkResults.Add($checkResult)
} else {
    # Target rules are wildcard patterns, so '*' allows any target
    $targetRules = @($allowedTargets.PSObject.Properties[$branchType].Value | ForEach-Object { [System.String] $_ })
    $targetAllowed = @($targetRules | Where-Object { $TargetBranch -like $_ }).Count -gt 0
    if ($targetAllowed) {
        $checkResult = [pscustomobject]@{
            Check    = 'Allowed target'
            Status   = 'Passed'
            Details  = "Target '$TargetBranch' is allowed for '$branchType' branches."
            NextStep = 'No action needed.'
        }
        $checkResults.Add($checkResult)
    } else {
        $targetError = "Target '$TargetBranch' is not allowed for '$branchType' branches."
        $failures.Add($targetError)

        $checkResult = [pscustomobject]@{
            Check    = 'Allowed target'
            Status   = 'Failed'
            Details  = $targetError
            NextStep = "Open the PR against one of: $($targetRules -join ', ')."
        }
        $checkResults.Add($checkResult)
    }
}

# Check 4: freshness. Resolve both revisions from local refs, or fetch them when running in a pipeline
if ($localMode) {
    # Prefer the local branch, fall back to the remote-tracking ref
    $sourceCandidates = @("refs/heads/$SourceBranch", "refs/remotes/$remoteName/$SourceBranch")
    $targetCandidates = @("refs/heads/$TargetBranch", "refs/remotes/$remoteName/$TargetBranch")
    $sourceRevision = $null
    $targetRevision = $null

    foreach ($candidate in $sourceCandidates) {
        & git show-ref --verify --quiet $candidate
        if ($LASTEXITCODE -eq 0) { $sourceRevision = $candidate; break }
    }

    foreach ($candidate in $targetCandidates) {
        & git show-ref --verify --quiet $candidate
        if ($LASTEXITCODE -eq 0) { $targetRevision = $candidate; break }
    }
} else {
    # Force-update the remote-tracking refs, the pipeline checkout may not contain either branch
    $sourceRevision = "refs/remotes/$remoteName/$SourceBranch"
    $targetRevision = "refs/remotes/$remoteName/$TargetBranch"
    $fetchOutput = & git fetch --no-tags $remoteName "+refs/heads/${SourceBranch}:${sourceRevision}" "+refs/heads/${TargetBranch}:${targetRevision}" 2>&1
    $fetchExitCode = $LASTEXITCODE

    if ($fetchExitCode -ne 0) {
        $fetchOutputLines = @($fetchOutput | ForEach-Object { ([System.String] $_).Trim() })
        $nonEmptyFetchOutputLines = @($fetchOutputLines | Where-Object { -not [System.String]::IsNullOrEmpty($_) })
        $fetchDetails = $nonEmptyFetchOutputLines -join ' '

        $freshnessError = "Could not fetch '$SourceBranch' and '$TargetBranch' from '$remoteName'. $fetchDetails"
        $failures.Add($freshnessError)

        $checkResult = [pscustomobject]@{
            Check    = 'Branch freshness'
            Status   = 'Failed'
            Details  = $freshnessError
            NextStep = 'Verify the refs exist and the pipeline identity has repository read access.'
        }
        $checkResults.Add($checkResult)

        # Nothing to compare after a failed fetch
        $sourceRevision = $null
        $targetRevision = $null
    }
}

# Three dots = symmetric difference; with --left-right --count it prints "<ahead> <behind>"
if ($sourceRevision -and $targetRevision) {
    $comparison = & git rev-list --left-right --count "$sourceRevision...$targetRevision"
    if ($LASTEXITCODE -ne 0) {
        $freshnessError = "Could not compare '$SourceBranch' with '$TargetBranch'."
        $failures.Add($freshnessError)

        $checkResult = [pscustomobject]@{
            Check    = 'Branch freshness'
            Status   = 'Failed'
            Details  = $freshnessError
            NextStep = 'Verify both refs exist and Git can read their history.'
        }
        $checkResults.Add($checkResult)
    } else {
        $counts = ([System.String] $comparison).Trim() -split '\s+'
        $aheadCount = [System.Int32] $counts[0]
        $behindCount = [System.Int32] $counts[1]
        $aheadBehind = "Ahead: $aheadCount; behind: $behindCount"

        if ($behindCount -gt 0) {
            $freshnessError = "Branch '$SourceBranch' is $behindCount commit(s) behind '$TargetBranch' and $aheadCount commit(s) ahead."
            $failures.Add($freshnessError)

            $checkResult = [pscustomobject]@{
                Check    = 'Branch freshness'
                Status   = 'Failed'
                Details  = $freshnessError
                NextStep = "Merge or rebase '$TargetBranch' into '$SourceBranch', then rerun validation."
            }
            $checkResults.Add($checkResult)
        } else {
            $checkResult = [pscustomobject]@{
                Check    = 'Branch freshness'
                Status   = 'Passed'
                Details  = "Branch is up to date with '$TargetBranch'. $aheadBehind."
                NextStep = 'No action needed.'
            }
            $checkResults.Add($checkResult)
        }
    }
} elseif ($localMode -and $checkResults.Check -notcontains 'Branch freshness') {
    # A pipeline fetch failure has already recorded its own freshness result
    $checkResult = [pscustomobject]@{
        Check    = 'Branch freshness'
        Status   = 'Skipped'
        Details  = "Local refs for '$SourceBranch' and/or '$TargetBranch' are missing."
        NextStep = 'Fetch or create both branches locally, then rerun validation.'
    }
    $checkResults.Add($checkResult)
}

# Build the Markdown summary
$summaryLines = @(
    '# Branch policy validation'
    ''
    "Source branch: $SourceBranch  `nTarget branch: $TargetBranch  `nAhead/behind: $aheadBehind  `nMode: $(if ($localMode) { 'Local' } else { 'Pull request' })"
    ''
    '| Check | Result | Details | Next step |'
    '|---|---|---|---|'
)

foreach ($result in $checkResults) {
    # Escape pipes and newlines so the text cannot break the table row
    $checkName = ([System.String] $result.Check) -replace '\|', '\|'
    $details = ([System.String] $result.Details) -replace '[\r\n]+', ' ' -replace '\|', '\|'
    $nextStep = ([System.String] $result.NextStep) -replace '[\r\n]+', ' ' -replace '\|', '\|'

    $statusDisplay = switch ($result.Status) {
        'Passed' { '<span style="color:green;font-weight:bold">✅ Passed</span>' }
        'Failed' { '<span style="color:red;font-weight:bold">❌ Failed</span>' }
        'Skipped' { '<span style="color:#9a6700;font-weight:bold">⏭️ Skipped</span>' }
        default { [System.String] $result.Status }
    }
    $summaryLines += "| $checkName | $statusDisplay | $details | $nextStep |"
}

if ($failures.Count -gt 0) {
    $summaryLines += @('', '## Issues', '')
    foreach ($failure in $failures) { $summaryLines += "- $failure" }
}

# Publish the summary: uploaded to the build in a pipeline, saved to a temp file locally
$agentTempDirectoryAvailable = -not [System.String]::IsNullOrWhiteSpace($env:AGENT_TEMPDIRECTORY)

if ($isAzurePipeline -and $agentTempDirectoryAvailable) {
    $summaryDirectory = $env:AGENT_TEMPDIRECTORY
} else {
    $summaryDirectory = [System.IO.Path]::GetTempPath()
}

$summaryPath = Join-Path $summaryDirectory "branch-policy-summary-$([System.Guid]::NewGuid().ToString('N')).md"
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding utf8

if ($isAzurePipeline) {
    Write-Host "##vso[task.uploadsummary]$summaryPath"
} else {
    Write-Host "Summary saved to: [$summaryPath]"
}

# Print the same results to the log
Write-Host ''
Write-Host 'Branch policy check results:'
Write-Host "Target branch: [$TargetBranch] | [$aheadBehind]"
foreach ($result in $checkResults) {
    $statusDisplay = switch ($result.Status) {
        'Passed' { '✅ Passed' }
        'Failed' { '❌ Failed' }
        'Skipped' { '⏭️ Skipped' }
        default { [System.String] $result.Status }
    }
    Write-Host "- [$statusDisplay] $($result.Check): $($result.Details)"
    if ($result.Status -ne 'Passed') { Write-Host "  Next step: [$($result.NextStep)]" }
}

# Pipelines report failures through logging commands, local runs through the exit code
if ($failures.Count -gt 0) {
    if ($isAzurePipeline) {
        foreach ($failure in $failures) {
            # Escape characters that are special in logging commands
            $escapedFailure = $failure.Replace('%', '%AZP25').Replace(']', '%5D').Replace("`r", '%0D').Replace("`n", '%0A')
            Write-Host "##vso[task.logissue type=error]$escapedFailure"
        }
        Write-Host "##vso[task.complete result=Failed;]Branch policy validation failed with [$($failures.Count)] issue(s)."
    } else {
        exit 1
    }
} else {
    Write-Host 'All executed branch policy checks passed.'
}
