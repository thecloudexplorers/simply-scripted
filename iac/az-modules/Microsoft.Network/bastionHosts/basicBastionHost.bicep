metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This module deploys an Azure Bastion Host using Standard SKU.'
}

@description('Name for the  Azure Bastion Host')
param bastionHostName string = 'djn-s-dmo-bas001'

@description('Region in which the vNet should be deployed')
param location string = 'West Europe'

@description('Id of the subnet in the Virtual Network where the Bastion Host should be deployed')
param subnetId string

@description('Id of the public IP address that should be associated with the Bastion Host')
param publicIpId string

resource bastionHost 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: true
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}
