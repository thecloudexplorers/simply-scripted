#Requires -PSEdition Core
#Requires -Modules Az.ResourceGraph
<#
    .SYNOPSIS
    Gets all subscriptions using the Management Group ancestors chain property.

    .DESCRIPTION
    This function reclusively retrieves all subscriptions that are members of the supplied Management Group and its children tree.
    This is done using the resource graph KQL query which expands the managementGroupAncestorsChain property.

    .PARAMETER ManagementGroupId
    Id of the management group from which the subscription will be searched

    .EXAMPLE
    $mgArgs = @{
        ManagementGroupId = 'mg100'
    }
    Get-SubscriptionsFromManagementGroupAncestorsChain @mgArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers

    .LINK
    https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.management.managementgroups.models.managementgroupdetails.managementgroupancestorschain?view=azure-dotnet-preview
    https://learn.microsoft.com/en-us/azure/governance/management-groups/resource-graph-samples?tabs=azure-cli
#>

function Get-SubscriptionsFromManagementGroupAncestorsChain {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ManagementGroupId
    )

    $managementGroupAncestorsChain = @"
resourcecontainers
| where type == 'microsoft.resources/subscriptions'
| mv-expand managementGroupParent = properties.managementGroupAncestorsChain
| where managementGroupParent.name =~ '$ManagementGroupId'
| project name, subscriptionId
| sort by name asc
"@

    $graphResultSubscriptions = Search-AzGraph -Query $managementGroupAncestorsChain -UseTenantScope

    return $graphResultSubscriptions
}
