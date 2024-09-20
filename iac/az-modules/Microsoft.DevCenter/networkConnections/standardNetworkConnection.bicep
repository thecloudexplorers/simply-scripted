@description('Location for the Network Connection')
param location string = resourceGroup().location

@description('The name of the Network Connection')
param devCenterNetworkConnectionName string

@description('The resource ID of the subnet')
param subnetId string

resource networkConnection 'Microsoft.DevCenter/networkConnections@2023-04-01' = {
  name: devCenterNetworkConnectionName
  location: location
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: subnetId
  }
}

output networkConnectionResourceId string = networkConnection.id
