metadata moduleMetadata = {
  title: 'Service Groups Hierarchy Deployment'
  description: '''Deploys a hierarchy of service groups using tiered approach where each tier is a child layer using the
  childServiceGroup module; each tier input supplies id, displayName, and parentId to build the nested structure.'''
  version: '0.0.1'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
}

targetScope = 'tenant'

// Tier 01
@description('''An array of configuration objects representing Tier 1 service groups. Each object must include an id,
displayName, and parentId.''')
param tier01ServiceGroups array = []

// Tier 02
@description('''An array of configuration objects representing Tier 2 service groups. Each object must include an id,
displayName, and parentId.''')
param tier02ServiceGroups array = []

// Tier 03
@description('''An array of configuration objects representing Tier 3 service groups. Each object must include an id,
displayName, and parentId.''')
param tier03ServiceGroups array = []

// Tier 04
@description('''An array of configuration objects representing Tier 4 service groups. Each object must include an id,
displayName, and parentId.''')
param tier04ServiceGroups array = []

// Tier 05
@description('''An array of configuration objects representing Tier 5 service groups. Each object must include an id,
displayName, and parentId.''')
param tier05ServiceGroups array = []

// Tier 06
@description('''An array of configuration objects representing Tier 6 service groups. Each object must include an id,
displayName, and parentId.''')
param tier06ServiceGroups array = []

// Tier 07
@description('''An array of configuration objects representing Tier 7 service groups. Each object must include an id,
displayName, and parentId.''')
param tier07ServiceGroups array = []

// Tier 08
@description('''An array of configuration objects representing Tier 8 service groups. Each object must include an id,
displayName, and parentId.''')
param tier08ServiceGroups array = []

// Tier 09
@description('''An array of configuration objects representing Tier 9 service groups. Each object must include an id,
displayName, and parentId.''')
param tier09ServiceGroups array = []

// Tier 10
@description('''An array of configuration objects representing Tier 10 service groups. Each object must include an id,
displayName, and parentId.''')
param tier10ServiceGroups array = []

var tenantRootServiceGroupId = tenant().tenantId

module tier01ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier01ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: tenantRootServiceGroupId
    }
  }
]

module tier02ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier02ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier01ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier03ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier03ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier02ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier04ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier04ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier03ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier05ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier05ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier04ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier06ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier06ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier05ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier07ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier07ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier06ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier08ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier08ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier07ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier09ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier09ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier08ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]

module tier10ServiceGroupModule '../az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep' = [
  for (currentServiceGroup, i) in tier10ServiceGroups: {
    name: 'service-group_${currentServiceGroup.id}'
    scope: tenant()
    dependsOn: [
      tier09ServiceGroupModule
    ]
    params: {
      id: currentServiceGroup.id
      displayName: currentServiceGroup.displayName
      parentServiceGroupId: currentServiceGroup.parentId
    }
  }
]
