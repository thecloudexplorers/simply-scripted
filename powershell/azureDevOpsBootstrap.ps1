#Requires -PSEdition Core
<#
    .SYNOPSIS
    Bootstraps an Azure DevOps organization by creating an organization-level
    group, granting it the 'Create new projects' permission, and adding the
    designated app registration service principal as a member.

    .DESCRIPTION
    This script performs one-time (idempotent) organization-level setup in
    Azure DevOps.

      1. Creating (or confirming the existence of) a named group at the
         Azure DevOps organization scope.
      2. Granting that group the 'Create new projects' permission.
      3. Adding the Entra ID service principal of the app registration to
         the group so that the app registration has sufficient permissions
         to create projects via the REST API.

    .PARAMETER RootRepoLocation
    The root directory location of the repository where the PowerShell
    functions are stored.

    .PARAMETER AdoOrganizationName
    Name of the Azure DevOps organization to bootstrap (without the URL
    prefix, e.g. 'my-organization').

    .PARAMETER AdoAccessToken
    A valid Azure DevOps bearer access token. Obtain this by running
    New-AdoAuthenticationContext.ps1

    .PARAMETER ServicePrincipalObjectId
    The Object ID of the Enterprise Application (service principal) in Entra
    ID that corresponds to the app registration. Visible in Entra ID under
    Enterprise Applications > <your app> > Overview > Object ID. This is NOT
    the Application (client) ID.

    .PARAMETER OrgGroupName
    Display name for the organization-level Azure DevOps group.

    .PARAMETER OrgGroupDescription
    Optional description for the organization-level group.

    .EXAMPLE
    $secret = ConvertTo-SecureString 'YOUR_CLIENT_SECRET' -AsPlainText -Force

    $authArgs = @{
        RootRepoLocation = 'C:\Repo'
        TenantId         = '00000000-0000-0000-0000-000000000000'
        ClientId         = '11111111-1111-1111-1111-111111111111'
        ClientSecret     = $secret
    }
    $adoAccessToken = New-AdoAuthenticationContext @authArgs

    $args = @{
        RootRepoLocation         = 'C:\Repo'
        AdoOrganizationName      = 'my-organization'
        AdoAccessToken           = $adoAccessToken
        ServicePrincipalObjectId = '22222222-2222-2222-2222-222222222222'
        OrgGroupName             = 'ADO Project Creators'
        OrgGroupDescription      = 'Grants Create new projects at org level'
    }
    .\azureDevOpsBootstrap.ps1 @args

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted


    The app registration must first be added to the Azure DevOps organization
    via Organization Settings > Users (or via Entra ID tenant-level policies).
    See:
    https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity
#>
[CmdLetBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $RootRepoLocation,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $AdoOrganizationName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $AdoAccessToken,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $ServicePrincipalObjectId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $OrgGroupName,

    [Parameter()]
    [System.String] $OrgGroupDescription = 'Organization-level group managed by azureDevOpsBootstrap'
)

# Set errors to break script execution
$ErrorActionPreference = 'Stop'

# Load New-AdoOrganizationGroup function via dot sourcing
Write-Host "Importing New-AdoOrganizationGroup.ps1"
$newAdoOrganizationGroupPath = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\New-AdoOrganizationGroup.ps1"
. $newAdoOrganizationGroupPath

# Load Set-AdoOrganizationGroupPermission function via dot sourcing
Write-Host "Importing Set-AdoOrganizationGroupPermission.ps1"
$setAdoOrganizationGroupPermissionPath = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\Set-AdoOrganizationGroupPermission.ps1"
. $setAdoOrganizationGroupPermissionPath

# Load Add-AdoOrganizationGroupMember function via dot sourcing
Write-Host "Importing Add-AdoOrganizationGroupMember.ps1"
$addAdoOrganizationGroupMemberPath = "{0}\{1}" -f $RootRepoLocation, "powershell\functions\Add-AdoOrganizationGroupMember.ps1"
. $addAdoOrganizationGroupMemberPath

# Build the Azure DevOps authentication header from the supplied bearer token
$adoAuthenticationHeader = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $AdoAccessToken
}

Write-Host "`n--- Azure DevOps Bootstrap for organization [$AdoOrganizationName] ---"

# 1 – Ensure the organization-level group exists (creates it if absent)
$orgGroupArgs = @{
    AdoOrganizationName     = $AdoOrganizationName
    GroupDisplayName        = $OrgGroupName
    GroupDescription        = $OrgGroupDescription
    AdoAuthenticationHeader = $adoAuthenticationHeader
}
$orgGroup = New-AdoOrganizationGroup @orgGroupArgs

# 2 – Grant the group the 'Create new projects' permission at org scope
$permissionArgs = @{
    AdoOrganizationName     = $AdoOrganizationName
    GroupDescriptor         = $orgGroup.descriptor
    PermissionDisplayName   = 'Create new projects'
    AdoAuthenticationHeader = $adoAuthenticationHeader
}
Set-AdoOrganizationGroupPermission @permissionArgs

# 3 – Add the app registration's service principal to the group
$memberArgs = @{
    AdoOrganizationName      = $AdoOrganizationName
    GroupDescriptor          = $orgGroup.descriptor
    ServicePrincipalObjectId = $ServicePrincipalObjectId
    AdoAuthenticationHeader  = $adoAuthenticationHeader
}
Add-AdoOrganizationGroupMember @memberArgs

Write-Host "--- Azure DevOps Bootstrap complete ---`n"
