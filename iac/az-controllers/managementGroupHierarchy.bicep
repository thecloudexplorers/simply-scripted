metadata resources = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: '''This Bicep file deploys a hierarchical structure of management groups
  following the Cloud Adoption Framework (CAF) design. It includes parameters for configuring
  up to six tiers of management groups, along with an optional default management group
  for new subscriptions and a flag for requiring write permissions for creating new
  management groups.'''
}
metadata resourceSets = {}

targetScope = 'tenant'

// Root management group (Tier 1)
@description('The root management group object, which includes an id and displayName. This management group will serve as the top-level parent for all other management groups.')
param tier0ManagementGroup object

// Tier 2 management groups
@description('An array of objects representing Tier 2 management groups. Each object must include an id and displayName. These will be children of the Tier 0 management group.')
param tier1ManagementGroups array = []

// Tier 3 management groups
@description('An array of objects representing Tier 3 management groups. Each object must include an id, displayName, and parentId. These will be children of the Tier 1 management groups.')
param tier2ManagementGroups array = []

// Tier 4 management groups
@description('An array of objects representing Tier 4 management groups. Each object must include an id, displayName, and parentId. These will be children of the Tier 2 management groups.')
param tier3ManagementGroups array = []

// Tier 5 management groups
@description('An array of objects representing Tier 5 management groups. Each object must include an id, displayName, and parentId. These will be children of the Tier 3 management groups.')
param tier4ManagementGroups array = []

// Tier 6 management groups
@description('An array of objects representing Tier 6 management groups. Each object must include an id, displayName, and parentId. These will be children of the Tier 4 management groups.')
param tier5ManagementGroups array = []

// Optional default management group for new subscriptions
@description('Optional. The ID of the default management group for new subscriptions. If not provided, new subscriptions will not be assigned to any management group by default.')
param IdOfDefaultManagementGroupForNewSubscriptions string = ''

// Optional flag for requiring write permissions for new management group creation
@description('Optional. Determines whether write permissions are required for creating new management groups. Default is true.')
param RequireWritePermissionsForNewManagementGroupCreation bool = true

var tenantRootManagementGroupId = tenant().tenantId

resource tier0ManagementGroupResource 'Microsoft.Management/managementGroups@2020-02-01' = {
  name: tier0ManagementGroup.id
  scope: tenant()
  properties: {
    displayName: tier0ManagementGroup.displayName
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', tenantRootManagementGroupId)
      }
    }
  }
}

module tier1ManagementGroupModule '../az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep' = [
  for (currentManagementGroup, i) in tier1ManagementGroups: {
    name: 'deploy-management-group_${currentManagementGroup.id}'
    scope: managementGroup(tier0ManagementGroup.id)
    params: {
      name: currentManagementGroup.id
      displayName: currentManagementGroup.displayName
      parentId: tier0ManagementGroupResource.id
    }
  }
]

module tier2ManagementGroupModule '../az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep' = [
  for (currentManagementGroup, i) in tier2ManagementGroups: {
    name: 'deploy-management-group_${currentManagementGroup.id}'
    scope: managementGroup(tier0ManagementGroup.id)
    params: {
      name: currentManagementGroup.id
      displayName: currentManagementGroup.displayName
      parentId: tenantResourceId('Microsoft.Management/managementGroups', currentManagementGroup.parentId)
    }
    dependsOn: [
      tier1ManagementGroupModule
    ]
  }
]

module tier3ManagementGroupModule '../az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep' = [
  for (currentManagementGroup, i) in tier3ManagementGroups: {
    name: 'deploy-management-group_${currentManagementGroup.id}'
    scope: managementGroup(tier0ManagementGroup.id)
    params: {
      name: currentManagementGroup.id
      displayName: currentManagementGroup.displayName
      parentId: tenantResourceId('Microsoft.Management/managementGroups', currentManagementGroup.parentId)
    }
    dependsOn: [
      tier2ManagementGroupModule
    ]
  }
]

module tier4ManagementGroupModule '../az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep' = [
  for (currentManagementGroup, i) in tier4ManagementGroups: {
    name: 'deploy-management-group_${currentManagementGroup.id}'
    scope: managementGroup(tier0ManagementGroup.id)
    params: {
      name: currentManagementGroup.id
      displayName: currentManagementGroup.displayName
      parentId: tenantResourceId('Microsoft.Management/managementGroups', currentManagementGroup.parentId)
    }
    dependsOn: [
      tier3ManagementGroupModule
    ]
  }
]

module tier5ManagementGroupModule '../az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep' = [
  for (currentManagementGroup, i) in tier5ManagementGroups: {
    name: 'deploy-management-group_${currentManagementGroup.id}'
    scope: managementGroup(tier0ManagementGroup.id)
    params: {
      name: currentManagementGroup.id
      displayName: currentManagementGroup.displayName
      parentId: tenantResourceId('Microsoft.Management/managementGroups', currentManagementGroup.parentId)
    }
    dependsOn: [
      tier4ManagementGroupModule
    ]
  }
]

resource requireAuthForNewMGCreation 'Microsoft.Management/managementGroups/settings@2021-04-01' = {
  name: '${tenantRootManagementGroupId}/default'
  properties: {
    requireAuthorizationForGroupCreation: RequireWritePermissionsForNewManagementGroupCreation
    defaultManagementGroup: empty(IdOfDefaultManagementGroupForNewSubscriptions)
      ? null
      : tenantResourceId('Microsoft.Management/managementGroups', IdOfDefaultManagementGroupForNewSubscriptions)
  }
  dependsOn: [
    tier5ManagementGroupModule
  ]
}
