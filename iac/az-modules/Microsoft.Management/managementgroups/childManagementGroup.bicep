metadata resources = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This bicep file deploys a management group as child of the specified parent management group'
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
