#Requires -PSEdition Core
#Requires -Modules Az.Resources
<#
    .SYNOPSIS
    Assigns the specified RBAC role to the specified principal, at any desired scope.

    .DESCRIPTION
    This function checks if the specified principal holds any RBAC role at the specified scope
    if this does not match with the input RBAC role for that principal, this function corrects it.

    Limitations:
    Only Azure AD Security groups and Service Principals (Enterprise Applications) are currently supported

    .PARAMETER RoleAssignmentScope
    Scope for the role assignment

    .PARAMETER ResourceGroupName
    Name of the target resource group

    .PARAMETER AzAdIdentityName
    DisplayName of either an AzADServicePrincipal or AzADGroup

    .PARAMETER RoleAssignments
    Array of Role Assignment names

    .PARAMETER AzAdObjectType
    Specify the type identity object, acceptable values are: azAdApplication, azAdSecurityGroup

    .EXAMPLE
    $inputArgs = @{
        RoleAssignmentScope = "/subscriptions/a61asf7f-12b6-4c13-b5d2-4302e728c57a/resourceGroups/My-Solution-RG"
        AzAdIdentityName = "my-security-group"
        RoleAssignments = Object[]$RoleAssignmentsArray
    }

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Set-AzRoleAssignments {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $RoleAssignmentScope,

        [ValidateNotNullOrEmpty()]
        [System.String] $AzAdIdentityName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $RoleAssignments,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AzAdObjectType
    )

    $azAdIdentity = $null
    switch ($AzAdObjectType) {
        azAdApplication {
            $azAdIdentity = Get-AzADServicePrincipal -Filter "DisplayName eq '$AzAdIdentityName'"
        }
        azAdSecurityGroup {
            $azAdIdentity = Get-AzADGroup -DisplayName $AzAdIdentityName
        }
        Default {
            Write-Error -Message "Unable to resolve the AzAdObjectType as an azAdSecurityGroup or an AzAdApplication" -ErrorAction Stop
        }
    }

    [PSCustomObject[]]$roleAssignmentexists = Get-AzRoleAssignment -Scope $RoleAssignmentScope 3> $null | Where-Object { $_.ObjectId -eq $azAdIdentity.Id -and $_.Scope -eq $RoleAssignmentScope }

    if ($null -eq $roleAssignmentexists ) {
        # to be able to compare objects, a dummy object is created if no role assignments exist for the identity in question
        $roleAssignmentexists = @()
        $roleAssignmentsDelta = Compare-Object -ReferenceObject $RoleAssignments -DifferenceObject $roleAssignmentexists
    } else {
        # role assignments exist for the identity in question, so a proper compare is done
        $roleAssignmentsDelta = Compare-Object -ReferenceObject $RoleAssignments -DifferenceObject $roleAssignmentexists.RoleDefinitionName
    }

    if ($roleAssignmentsDelta.Count -gt 0) {
        Write-Information -MessageData "   Delta detected in the RoleAssignments, applying drift control"

        $roleAssignmentsDelta.ForEach{
            $delta = $_

            switch ($delta.SideIndicator) {
                '=>' {
                    # Removing excessive role assignments
                    $rogueRoleAssignment = $roleAssignmentexists | Where-Object { $_.RoleDefinitionName -eq $delta.InputObject }

                    Write-Information -MessageData "   Removing rogue role assignment [$($rogueRoleAssignment.RoleDefinitionName)]"
                    Remove-AzRoleAssignment -InputObject $rogueRoleAssignment 3> $null
                    Write-Information -MessageData "   UPDATED: Rogue role assignment removed"
                }
                '<=' {
                    # Adding missing role assignments
                    Write-Information -MessageData "   Adding missing assignment [$($delta.InputObject)]"
                    New-AzRoleAssignment -ObjectId $azAdIdentity.Id -RoleDefinitionName $delta.InputObject -Scope $RoleAssignmentScope 1> $null
                    Write-Information -MessageData "   UPDATED: Missing role assignment added"
                }
                Default {
                    Write-Error -Message "Something went wrong compairing role Assignments, unsupported side indicator [$($delta.SideIndicator)]" -ErrorAction Stop
                }
            }
        }
    } else {
        Write-Information -MessageData "   SUCCESS: no drift has been detected all role assignments are correct"
    }
}
