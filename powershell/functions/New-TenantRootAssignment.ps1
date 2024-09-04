#Requires -PSEdition Core
#Requires -Modules Az.Accounts

<#
    .SYNOPSIS
    This function adds any existing Entra ID Object as a Tenant Root Owner.

    .DESCRIPTION
    This script checks if the specified Entra ID Object exists and is already
    an Owner on the Tenant Root. If not, the specified identity is added.
    Required permissions are assumed to be in place.
    Supported Identity types:
    - User
    - Security Group
    - Enterprise Application

    .PARAMETER EnIdIdentityName
    Name of an Entra ID principal present in the tenant.

    .PARAMETER EnIdRoleDefinition
    Name of an Entra ID role definition present in the tenant.

    .EXAMPLE
    $newTenantOwnerArgs = @{
        EnIdIdentityName = "YOUR_IDENTITY_OBJECT_HERE"
    }

    .\New-TenantRootAssignment.ps1 @newTenantOwnerArgs

    .NOTES
    Version     : 2.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://github.com/Azure/Enterprise-Scale/blob/ff07fc89f6d13fe3bd52ddf034b4d136de1c6116/docs/wiki/Deploying-ALZ-Pre-requisites.md
    https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-to-management-group?tabs=azure-powershell&WT.mc_id=DT-MVP-5004039
    https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin?WT.mc_id=DT-MVP-5004039
#>
function New-TenantRootAssignment {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $EnIdIdentityName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $EnIdRoleDefinition
    )

    # Set errors to break script execution
    $ErrorActionPreference = 'Stop'

    # Validate provided role name
    $roleExists = Get-AzRoleDefinition -Name $EnIdRoleDefinition

    if ($null -ne $roleExists) {
        $tenantRootScope = '/'

        Write-Host " Resolving identity type for [$EnIdIdentityName]"

        # Initialize the Entra ID Identity variable
        $azAdIdentity = $null

        # Check if the identity is a Service Principal
        $azAdIdentity = Get-AzADServicePrincipal -Filter "DisplayName eq '$EnIdIdentityName'"
        if ($null -ne $azAdIdentity) {
            Write-Host " Identity has been resolves as a Entra ID Service Principal"

        } else {
            # Check if the identity is a Security Group
            $azAdIdentity = Get-AzADGroup -DisplayName $EnIdIdentityName

            if ($null -ne $azAdIdentity) {
                Write-Host " Identity has been resolves as an Entra ID Security Group"
            } else {
                # Check if the identity is a User
                $azAdIdentity = Get-AzADUser -DisplayName $EnIdIdentityName
                if ($null -ne $azAdIdentity) {
                    Write-Host " Identity has been resolves as an Entra ID User"
                } else {
                    Write-Error -Message "Supplied Identity does not exists or the current principal does not have access to it" -ErrorAction Stop
                }
            }
        }

        # Get all role assignments for the current identity on tenant root scope
        [PSCustomObject[]]$roleAssignmentExists = Get-AzRoleAssignment -Scope $tenantRootScope 3> $null | Where-Object { $_.ObjectId -eq $azAdIdentity.Id -and $_.Scope -eq $tenantRootScope }

        # Filter the assignments on 'Owner' to check if the correct one has been set
        $assignmentExists = $roleAssignmentExists | Where-Object { $_.Scope -eq $tenantRootScope }

        # If the assignment does not exist, create a new role assignment
        if ($null -eq $assignmentExists) {
            New-AzRoleAssignment -Scope '/' -RoleDefinitionName $EnIdRoleDefinition -ObjectId $azAdIdentity.Id 1> $null
            Write-Host " Identity [$EnIdIdentityName] has been added"
        } else {
            Write-Host " Identity [$EnIdIdentityName] already has [$EnIdRoleDefinition] assignment on scope [$tenantRootScope]"
        }

    } else {
        Write-Error -Message "Role definition [$EnIdRoleDefinition] does not exists, make sure to provide a role definition present in the current tenant" -ErrorAction Stop
    }
}
