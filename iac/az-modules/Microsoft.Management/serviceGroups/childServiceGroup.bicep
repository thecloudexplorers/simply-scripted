@minLength(1)
@maxLength(243)
@description('Globally unique identifier for the service group, may only contain ASCII letters, digits, and: - _ ( ) . ~')
param id string

@minLength(1)
@maxLength(243)
@description('Display name for the service group')
param displayName string

@minLength(1)
@maxLength(243)
@description('Parent service group Id under which this service group will be created')
param parentServiceGroupId string

targetScope = 'tenant'

resource serviceGroup 'Microsoft.Management/serviceGroups@2024-02-01-preview' = {
  scope: tenant()
  name: id
  properties: {
    displayName: displayName
    parent: {
      resourceId: '/providers/Microsoft.Management/serviceGroups/${parentServiceGroupId}'
    }
  }
}
