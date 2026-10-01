<#
    .SYNOPSIS
    Notifies the last committer of stale feature/hotfix branches by email.

    .DESCRIPTION
    Scans the repositories listed in notifyStaleBranches.config.json for branches matching the
    configured prefixes via the Azure DevOps REST API. Branches whose last commit is older than
    the inactivity threshold are reported, and their last committer is emailed via Azure
    Communication Services, unless -DryRun is specified.

    .PARAMETER InactiveDays
    The inactivity threshold, in days.

    .PARAMETER RootRepoLocation
    The root repository location. Used to resolve the config file and companion script paths.

    .PARAMETER OrganizationUrl
    Azure DevOps organization URL, e.g. the pipeline's System.CollectionUri.

    .PARAMETER Project
    Azure DevOps project name, e.g. the pipeline's System.TeamProject.

    .PARAMETER AccessToken
    Azure DevOps OAuth access token used for REST calls (sent as a Bearer token), e.g. the pipeline's System.AccessToken.

    .PARAMETER DryRun
    Reports stale branches and intended recipients without sending any email.

    .EXAMPLE
    $notifyStaleBranchesParameters = @{
        RootRepoLocation = '.'
        InactiveDays = 21
        OrganizationUrl = 'https://dev.azure.com/contoso'
        Project = 'MyProject'
        AccessToken = $accessToken
        DryRun = $true
    }
    ./notifyStaleBranches.ps1 @notifyStaleBranchesParameters

    Reports stale branches and intended recipients without sending any email.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $RootRepoLocation,

    [Parameter(Mandatory)]
    [ValidateRange(1, 3650)]
    [System.Int32] $InactiveDays,

    # Must be the pipeline's own org/project; the OAuth token is only authorized there.
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [System.String] $OrganizationUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $Project,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $AccessToken,

    [System.Management.Automation.SwitchParameter] $DryRun
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path -Path $RootRepoLocation -ChildPath 'notifyStaleBranches.config.json'

# Load Invoke-DevOpsApi function via dot sourcing
$invokeDevOpsApi = Join-Path -Path $RootRepoLocation -ChildPath 'Invoke-DevOpsApi.ps1'
. $invokeDevOpsApi

# Load and validate the configuration
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Configuration file [$configPath] was not found."
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "Could not read JSON configuration [$configPath]: $_"
}

$organizationUrl = $OrganizationUrl.TrimEnd('/')

# Add or remove entries here to change scan scope; no pipeline changes are needed.
$configuredRepositories = @($config.repositories | ForEach-Object { [System.String] $_ })
$repositories = @($configuredRepositories | Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) })
if ($repositories.Count -eq 0) {
    throw 'repositories in the JSON configuration must contain one or more repository names.'
}

$branchPrefixes = @($config.branchPrefixes | ForEach-Object { [System.String] $_ })
$invalidBranchPrefixes = @($branchPrefixes | Where-Object { $_ -notmatch '^[a-z0-9-]+$' })
if ($branchPrefixes.Count -eq 0 -or $invalidBranchPrefixes.Count -gt 0) {
    throw 'branchPrefixes in the JSON configuration must contain one or more lowercase branch prefixes.'
}

$senderAddress = [System.String] $config.email.senderAddress

$apiHeaders = @{ Authorization = "Bearer $AccessToken" }

$cutoffUtc = [System.DateTime]::UtcNow.AddDays(-$InactiveDays)
$staleBranches = [System.Collections.Generic.List[System.Object]]::new()

# Scan each repository: list matching branches, resolve their tip commits, keep the stale ones
foreach ($repository in $repositories) {
    $encodedProject = [System.Uri]::EscapeDataString($Project)
    $encodedRepository = [System.Uri]::EscapeDataString($repository)

    # Group branches by tip commit so each commit is looked up only once
    $branchesByCommitId = @{}
    foreach ($prefix in $branchPrefixes) {
        $refsFilter = [System.Uri]::EscapeDataString("heads/$prefix/")
        $refsUri = "$organizationUrl/$encodedProject/_apis/git/repositories/$encodedRepository/refs?filter=$refsFilter&api-version=7.1"

        try {
            $refsResponse = Invoke-DevOpsApi -Uri $refsUri -Headers $apiHeaders
        } catch {
            Write-Warning "Could not list [$prefix]/* branches for repository [$repository]; skipping it: [$_]"
            continue
        }

        foreach ($ref in @($refsResponse.value)) {
            $branchName = ([System.String] $ref.name) -replace '^refs/heads/', ''
            $branchNameMissing = [System.String]::IsNullOrWhiteSpace($branchName)
            $objectIdMissing = [System.String]::IsNullOrWhiteSpace($ref.objectId)
            if ($branchNameMissing -or $objectIdMissing) {
                continue
            }

            if (-not $branchesByCommitId.ContainsKey($ref.objectId)) {
                $branchesByCommitId[$ref.objectId] = [System.Collections.Generic.List[System.String]]::new()
            }
            $branchesByCommitId[$ref.objectId].Add($branchName)
        }
    }

    if ($branchesByCommitId.Count -eq 0) {
        continue
    }

    # The commitsBatch API accepts a limited number of ids per call, so request them in chunks
    $commitIds = @($branchesByCommitId.Keys)
    $commitsByCommitId = @{}
    $batchSize = 200
    for ($offset = 0; $offset -lt $commitIds.Count; $offset += $batchSize) {
        $lastIndex = [Math]::Min($offset + $batchSize, $commitIds.Count) - 1
        $batch = $commitIds[$offset..$lastIndex]
        $commitsBatchUri = "$organizationUrl/$encodedProject/_apis/git/repositories/$encodedRepository/commitsBatch?api-version=7.1"

        try {
            $commitsResponse = Invoke-DevOpsApi -Uri $commitsBatchUri -Method 'Post' -Body @{ ids = $batch } -Headers $apiHeaders
        } catch {
            Write-Warning "Could not read commit details for repository [$repository]; skipping its branches: [$_]"
            continue
        }

        foreach ($commit in @($commitsResponse.value)) {
            $commitsByCommitId[$commit.commitId] = $commit
        }
    }

    foreach ($commitId in $branchesByCommitId.Keys) {
        $commit = $commitsByCommitId[$commitId]
        if ($null -eq $commit) {
            Write-Warning "Commit [$commitId] details were not returned for repository [$repository]; skipping its branch(es)."
            continue
        }

        # Committer, not author, reflects who last pushed the branch tip.
        $lastCommitUtc = [System.DateTimeOffset]::Parse($commit.committer.date).UtcDateTime
        if ($lastCommitUtc -ge $cutoffUtc) {
            continue
        }

        # ADO may return the email wrapped in angle brackets
        $committerEmail = ([System.String] $commit.committer.email).Trim().Trim('<', '>')
        if ($committerEmail -notmatch '^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$') {
            Write-Warning "Committer email for commit [$commitId] in repository [$repository] is missing or invalid; cannot notify its owner."
            $committerEmail = $null
        }

        $branchInactiveDays = [System.Int32][System.Math]::Floor(([System.DateTime]::UtcNow - $lastCommitUtc).TotalDays)

        foreach ($branchName in $branchesByCommitId[$commitId]) {
            $encodedBranchName = [System.Uri]::EscapeDataString($branchName)
            $branchUrl = "$organizationUrl/$encodedProject/_git/${encodedRepository}?version=GB$encodedBranchName"

            $staleBranch = [pscustomobject]@{
                Repository       = $repository
                Branch           = $branchName
                BranchUrl        = $branchUrl
                LastCommitUtc    = $lastCommitUtc
                InactiveDays     = $branchInactiveDays
                CommitOwnerEmail = $committerEmail
            }
            $staleBranches.Add($staleBranch)
        }
    }
}

# Report results
if ($staleBranches.Count -eq 0) {
    Write-Host "No configured branch types have been inactive for at least [$InactiveDays] days."
    exit 0
}

Write-Host "Found [$($staleBranches.Count)] stale branch(es), using a [$InactiveDays]-day inactivity threshold:"
foreach ($branch in ($staleBranches | Sort-Object CommitOwnerEmail, Repository, Branch)) {
    $lastCommitDate = $branch.LastCommitUtc.ToString('yyyy-MM-dd')
    Write-Host "❌ [$($branch.Repository)]/[$($branch.Branch)]: inactive for [$($branch.InactiveDays)] days; last commit [$lastCommitDate] UTC; commit owner [$($branch.CommitOwnerEmail)]"
}
Write-Host "Finished processing stale branches."

# Branches without a valid committer email are reported above but cannot be notified
$notifiableBranches = @($staleBranches | Where-Object { -not [System.String]::IsNullOrWhiteSpace($_.CommitOwnerEmail) })
$branchesByCommitOwner = @($notifiableBranches | Group-Object CommitOwnerEmail)

if ($DryRun) {
    foreach ($commitOwnerGroup in $branchesByCommitOwner) {
        Write-Host "DRY RUN: would email [$($commitOwnerGroup.Name)] about [$($commitOwnerGroup.Count)] stale branch(es)."
    }
    exit 0
}

# Prerequisites for sending email
if ([System.String]::IsNullOrWhiteSpace($senderAddress)) {
    throw 'Set email.senderAddress in the JSON configuration, or use -DryRun to preview.'
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required to send ACS email notifications.'
}

# Using the az CLI 'communication' extension instead of the Az.Communication PowerShell module,
# because that module is still in preview as of 2026-09-30.
& az extension show --name communication --output none 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "The Azure CLI 'communication' extension is not installed; installing it now."
    & az extension add --name communication --only-show-errors --output none 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not install the Azure CLI 'communication' extension. Install it manually with: az extension add --name communication"
    }
}

$failedNotifications = [System.Collections.Generic.List[System.String]]::new()
Write-Host "Notifying last committers of stale branches..."

# One email per committer, listing all of their stale branches
foreach ($commitOwnerGroup in $branchesByCommitOwner) {
    $branchesForCommitOwner = @($commitOwnerGroup.Group | Sort-Object Repository, Branch)
    $branchLines = foreach ($branch in $branchesForCommitOwner) {
        $lastCommitDate = $branch.LastCommitUtc.ToString('yyyy-MM-dd')
        "- $($branch.Repository)/$($branch.Branch): inactive for $($branch.InactiveDays) days (last commit $lastCommitDate UTC) - $($branch.BranchUrl)"
    }
    $subject = "Stale Git branches: inactive for $InactiveDays+ days"
    $emailBody = @(
        "The following configured branch(es) have had no new commits for at least $InactiveDays days:"
        ''
        $branchLines
        ''
        'Please update, merge, or remove branches that are no longer needed.'
    ) -join [Environment]::NewLine

    try {
        $sendArguments = @(
            'communication', 'email', 'send',
            '--sender', $senderAddress,
            '--to', $commitOwnerGroup.Name,
            '--subject', $subject,
            '--text', $emailBody,
            '--output', 'json'
        )
        $sendOutput = & az @sendArguments 2>&1
        $sendExitCode = $LASTEXITCODE
        if ($sendExitCode -ne 0) {
            throw "Azure CLI exited with code ${sendExitCode}: $($sendOutput -join ' ')"
        }

        $sendResult = ($sendOutput -join [Environment]::NewLine) | ConvertFrom-Json
        # A zero exit code does not guarantee delivery; the operation status must be 'Succeeded'
        if ($sendResult.status -ne 'Succeeded') {
            throw "ACS email operation status was '$($sendResult.status)': $($sendResult.error | ConvertTo-Json -Compress -Depth 5)"
        }
        Write-Host "Sent ACS email notification to [$($commitOwnerGroup.Name)]."
    } catch {
        # Keep going so one failed recipient does not block the others; fail at the end
        $failedNotifications.Add("Could not email $($commitOwnerGroup.Name): $_")
    }
}

if ($failedNotifications.Count -gt 0) {
    throw ($failedNotifications -join '; ')
}
