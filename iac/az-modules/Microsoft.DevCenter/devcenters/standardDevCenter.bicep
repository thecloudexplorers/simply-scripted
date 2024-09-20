@description('Location for the DevCenter')
param location string = resourceGroup().location

@description('The name of the DevCenter')
param devCenterName string

resource devCenter 'Microsoft.DevCenter/devcenters@2023-04-01' = {
  name: devCenterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

output devCenterResourceId string = devCenter.id
output devCenterPrincipalId string = devCenter.identity.principalId
