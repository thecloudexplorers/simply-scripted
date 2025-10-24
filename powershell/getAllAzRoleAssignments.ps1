
<#
.SYNOPSIS
    Exports Azure role assignments to CSV with resolved principal names.

.DESCRIPTION
    Orchestrates the export of Azure role assignments by loading and executing
    the Export-AzRoleAssignmentsWithPrincipalNames function. Handles module
    installation, Azure authentication, and generates a timestamped CSV output.

.PARAMETER RootRepoLocation
    Root directory path of the repository where the function is located in the
    powershell\functions\Export-AzRoleAssignmentsWithPrincipalNames.ps1 file.

.PARAMETER OutputFolderPath
    Directory path where the CSV file will be saved with the naming convention
    RoleAssignments_YYYY-MM-DD_HH_MM_SS.csv using the current timestamp.

.EXAMPLE
    .\getAllAzRoleAssignments.ps1 -RootRepoLocation "C:\repos\simply-scripted" `
        -OutputFolderPath "C:\reports"

    Exports all role assignments to C:\reports\RoleAssignments_2025-10-24.csv

.NOTES
    Version     : 0.0.1
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    Requires Az.ResourceGraph, Az.Accounts, and Az.Resources PowerShell modules.
    The script will prompt to install any missing modules if not available.
#>

param(
    [Parameter(Mandatory)]
    [System.String] $RootRepoLocation,

    [Parameter(Mandatory)]
    [System.String] $OutputFolderPath
)

# Set execution preferences
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Requires Az modules
$requiredModules = @('Az.ResourceGraph', 'Az.Accounts', 'Az.Resources')

foreach ($module in $requiredModules) {
    Write-Warning "Module [$module] is not installed."

    $confirm = Read-Host "Do you want to install module [$module]? (Y/N)"
    if ($confirm -eq 'Y' -or $confirm -eq 'y') {
        Install-Module -Name $module -Scope CurrentUser -Force
    } else {
        Write-Error "Module [$module] is required. Exiting script." -ErrorId Stop
    }
    Write-Information -MessageData"Importing module [$module]"
    Import-Module $module -ErrorAction Stop
}



# Connect to Azure if not already connected
try {
    $azContext = Get-AzContext
    if (-not $azContext) {
        Write-Information -MessageData "Connecting to Azure..."
        Connect-AzAccount
    }
    Write-Information -MessageData "Connected to Azure as [$($azContext.Account.Id)]"
} catch {
    Write-Error "Failed to connect to Azure [$_]" -ErrorAction Stop
}


# Load Set-AzRoleAssignments function via dot sourcing
Write-Information -MessageData "Importing Export-AzRoleAssignmentsWithPrincipalNames.ps1"
$setAzRoleAssignments = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\Export-AzRoleAssignmentsWithPrincipalNames.ps1"
. $setAzRoleAssignments

$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH_mm_ss"
$OutputPath = "{0}\RoleAssignments_{1}.csv" -f $OutputFolderPath, $currentDateTime

Export-AzRoleAssignmentsWithPrincipalNames -OutputPath $OutputPath
