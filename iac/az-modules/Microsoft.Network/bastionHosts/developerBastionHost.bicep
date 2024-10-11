metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This module deploys an Azure Bastion Host using Standard SKU.'
}

@description('Name for the  Azure Bastion Host')
param bastionHostName string = 'djn-s-dmo-bas002'

@description('Region in which the vNet should be deployed')
param location string = 'West Europe'

// @description('Id of the subnet in the Virtual Network where the Bastion Host should be deployed')
// param subnetId string

resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: '/subscriptions/6aad71f7-ec30-4684-990a-34d3bc6fe7d9/resourceGroups/tnp-sep-p-rg001/providers/Microsoft.Network/virtualNetworks/tnp-sep-p-vnet002'
    }
    ipConfigurations: []
  }
}
