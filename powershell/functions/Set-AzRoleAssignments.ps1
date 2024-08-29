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

    .VERSION
    2.0.0

    .PARAMETER RoleAssignmentScope
    Scope for the role assignment

    .PARAMETER ResourceGroupName
    Name of the target resource group

    .PARAMETER EnIdIdentityName
    DisplayName of either an EnIdServicePrincipal or EnIdGroup

    .PARAMETER RoleAssignments
    Array of Role Assignment names

    .PARAMETER EnIdObjectType
    Specify the type identity object, acceptable values are: enIdApplication, enIdSecurityGroup

    .EXAMPLE
    $inputArgs = @{
        RoleAssignmentScope = "/subscriptions/a61asf7f-12b6-4c13-b5d2-4302e728c57a/resourceGroups/My-Solution-RG"
        EnIdIdentityName = "my-security-group"
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
        [System.String] $EnIdIdentityName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $RoleAssignments,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('enIdApplication', 'enIdSecurityGroup')]
        [System.String] $EnIdObjectType
    )

    $enIdIdentity = $null
    switch ($EnIdObjectType) {
        enIdApplication {
            $enIdIdentity = Get-AzADServicePrincipal -Filter "DisplayName eq '$EnIdIdentityName'"
        }
        enIdSecurityGroup {
            $enIdIdentity = Get-AzADGroup -DisplayName $EnIdIdentityName
        }
        Default {
            Write-Error -Message "Unable to resolve the EnIdObjectType as an enIdSecurityGroup or an enIdApplication" -ErrorAction Stop
        }
    }

    [PSCustomObject[]]$roleAssignmentExists = Get-AzRoleAssignment -Scope $RoleAssignmentScope 3> $null | Where-Object { $_.ObjectId -eq $enIdIdentity.Id -and $_.Scope -eq $RoleAssignmentScope }

    if ($null -eq $roleAssignmentExists ) {
        # To be able to compare objects, a dummy object is created if no role assignments exist for the identity in question
        $roleAssignmentExists = @()
        $roleAssignmentsDelta = Compare-Object -ReferenceObject $RoleAssignments -DifferenceObject $roleAssignmentExists
    } else {
        # Tole assignments exist for the identity in question, so a proper compare is done
        $roleAssignmentsDelta = Compare-Object -ReferenceObject $RoleAssignments -DifferenceObject $roleAssignmentExists.RoleDefinitionName
    }

    if ($roleAssignmentsDelta.Count -gt 0) {
        Write-Host "   Delta detected in the RoleAssignments, applying drift control"

        $roleAssignmentsDelta.ForEach{
            $delta = $_

            switch ($delta.SideIndicator) {
                '=>' {
                    # Removing excessive role assignments
                    $rogueRoleAssignment = $roleAssignmentExists | Where-Object { $_.RoleDefinitionName -eq $delta.InputObject }

                    Write-Host "   Removing rogue role assignment [$($rogueRoleAssignment.RoleDefinitionName)]"
                    Remove-AzRoleAssignment -InputObject $rogueRoleAssignment 3> $null
                    Write-Host "   UPDATED: Rogue role assignment removed"
                }
                '<=' {
                    # Adding missing role assignments
                    Write-Host "   Adding missing assignment [$($delta.InputObject)]"
                    New-AzRoleAssignment -ObjectId $enIdIdentity.Id -RoleDefinitionName $delta.InputObject -Scope $RoleAssignmentScope 1> $null
                    Write-Host "   UPDATED: Missing role assignment added"
                }
                Default {
                    Write-Error -Message "Something went wrong comparing role Assignments, unsupported side indicator [$($delta.SideIndicator)]" -ErrorAction Stop
                }
            }
        }
    } else {
        Write-Host "   SUCCESS: no drift has been detected all role assignments are correct"
    }
}
