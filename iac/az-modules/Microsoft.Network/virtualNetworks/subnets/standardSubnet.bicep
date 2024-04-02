metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This module deploys an Azure Virtual Network Subnet.'
}
@description('Name of the subnet')
param subnetName string

@description('Ip adress range for the subnet')
param addressPrefix string

@description('Name of the parent vNet where the subnet will be created.')
param parentVnetName string

@description('Optional. Network Security Group id to associate with the subnet. If not provided, no NSG will be associated with the subnet.')
param nsgId string?

resource existingParentVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: parentVnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: subnetName
  parent: existingParentVnet
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: !empty(nsgId)
      ? {
          id: nsgId
        }
      : null
  }
}

output subnetId string = subnet.id
