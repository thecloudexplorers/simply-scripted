@description('Name for the Virtual Network')
param virtualNetworkName string = 'djn-s-dmo-vnet001'

@description('Name of the subnet for the jump box VM')
param jumpVmSubnetName string

@description('Region in which the vNet should be deployed')
param location string = 'West Europe'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/22'
      ]
    }
    // Due to a bicep limitation in which when a bicep deployment is rerun again it tries to delete and recreate the existing subnets
    // however since htere are resources attached to those subnets it fails to delete them and the deployment fails.
    // We need to define the subnets in the properties and not as separate resoruces or as a module.
    // For more details see following links:
    // https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-virtual-networks
    // https://github.com/Azure/bicep-types-az/issues/1687#issuecomment-1623960076
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/25'
        }
      }
      {
        name: jumpVmSubnetName
        properties: {
          addressPrefix: '10.0.2.0/25'
        }
      }
    ]
  }

  resource AzureBastionSubnetExisting 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }

  resource jumpVmSubnetExisting 'subnets' existing = {
    name: jumpVmSubnetName
  }
}

output bastionSubnetId string = virtualNetwork::AzureBastionSubnetExisting.id
output jumpVmSubnetId string = virtualNetwork::jumpVmSubnetExisting.id
