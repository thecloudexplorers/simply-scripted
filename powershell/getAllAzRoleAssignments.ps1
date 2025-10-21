
$RootRepoLocation = "C:\dev\gh\thecloudexplorers\simply-scripted"
$OutputFolderPath = "C:\temp"

# Set execution preferences
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Requires Az modules
$requiredModules = @('Az.ResourceGraph', 'Az.Accounts', 'Az.Resources')

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Warning "Module '$module' is not installed. Installing..."
        Install-Module -Name $module -Scope CurrentUser -Force
    }
    Import-Module $module -ErrorAction Stop
}

# Connect to Azure if not already connected
try {
    $azContext = Get-AzContext
    if (-not $azContext) {
        Write-Host "Connecting to Azure..." -ForegroundColor Cyan
        Connect-AzAccount
    }
    Write-Host "Connected to Azure as: $($azContext.Account.Id)" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Azure: $_"
    exit 1
}


# Load Set-AzRoleAssignments function via dot sourcing
Write-Host "Importing Export-AzRoleAssignmentsWithPrincipalNames.ps1"
$setAzRoleAssignments = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\Export-AzRoleAssignmentsWithPrincipalNames.ps1"
. $setAzRoleAssignments

$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH_mm_ss"
$OutputPath = "{0}\RoleAssignments_{1}.csv" -f $OutputFolderPath, $currentDateTime

Export-AzRoleAssignmentsWithPrincipalNames -OutputPath $OutputPath
