@description('Name for the Virtual Network')
param virtualNetworkName string = 'djn-s-dmo-vnet001'

@description('Region in which the vNet should be deployed')
param location string = 'West Europe'

@description('Name of the first subnet in the Virtual Network')
param firstSubnetName string = 'AzureBastionSubnet'

@description('Name of the second subnet in the Virtual Network')
param secondSubnetName string = 'djn-s-dmo-snet002'

@description('Name of the second subnet in the Virtual Network')
param thirdSubnetName string = 'djn-s-dmo-snet003'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/22'
      ]
    }
    subnets: [
      {
        name: firstSubnetName
        properties: {
          addressPrefix: '10.0.1.0/25'
        }
      }, {
        name: secondSubnetName
        properties: {
          addressPrefix: '10.0.2.0/25'
        }
      }, {
        name: thirdSubnetName
        properties: {
          addressPrefix: '10.0.3.0/25'
        }
      }
    ]
  }
}

output bastionSubnetId string = virtualNetwork.properties.subnets[0].id
output hopVmSubnetId string = virtualNetwork.properties.subnets[1].id
