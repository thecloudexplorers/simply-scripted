metadata moduleMetadata = {
  author: 'Jev Suchoi'
  description: 'This module deploys an Azure Virtual Network with an address space of 10.0.0.0/22'
  version: '1.0.0'
}

@description('''
Specify new for a greenfield deployment of the vNet otherwise specify existing.
This is needed due to a a bicep limitation, when a vNet deployment is rerun without subnets directly specified in the vNet resoruce
the ARM engine tries to delete and recreate the existing subnets, however since there are resources attached to those subnets
it fails to delete them and the deployment fails. Therefore teh vNet deployment is only rerun when new is specified.
For more details see following links:
https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-virtual-networks
https://github.com/Azure/bicep-types-az/issues/1687#issuecomment-1623960076
''')
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
