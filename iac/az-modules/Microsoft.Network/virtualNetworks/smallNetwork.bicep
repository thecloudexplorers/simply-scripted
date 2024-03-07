@allowed([
  'new'
  'existing'
])
param newOrExisting string = 'existing'

@description('Name for the Virtual Network')
param virtualNetworkName string = 'djn-s-dmo-vnet001'

@description('Region in which the vNet should be deployed')
param location string = 'West Europe'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = if (newOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/22'
      ]
    }
  }
}

resource virtualNetworkExisting 'Microsoft.Network/virtualNetworks@2023-04-01' existing = if (newOrExisting == 'existing') {
  name: virtualNetworkName
}

output vNetId string = ((newOrExisting == 'new') ? virtualNetwork.id : virtualNetworkExisting.id)
