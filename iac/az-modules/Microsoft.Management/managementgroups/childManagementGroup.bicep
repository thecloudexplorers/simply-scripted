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

targetScope = 'managementGroup'

@description('Unique identifier for the management group')
@minLength(5)
@maxLength(10)
param name string

@description('Display name for the management group')
@minLength(3)
@maxLength(50)
param displayName string

@description('Parent Id of the parent management group')
@minLength(1)
param parentId string

resource managementGroup 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: name
  scope: tenant()
  properties: {
    displayName: displayName
    details: {
      parent: {
        id: parentId
      }
    }
  }
}

@description('Id of the newly created management group')
output groupId string = managementGroup.id
