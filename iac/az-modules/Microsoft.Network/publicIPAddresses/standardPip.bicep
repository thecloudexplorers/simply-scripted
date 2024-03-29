metadata moduleMetadata = {
  author: 'Jev Suchoi'
  description: 'This module deploys an Azure Public IP Address based on Standard SKU.'
  version: '1.0.0'
}

@description('Name for the Public IP Address resource')
param publicIpAddressName string = 'djn-s-dmo-vnet001'

@description('Region in which the Public IP Address should be deployed')
param location string = 'West Europe'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

output publicIpAddressId string = publicIp.id
