@description('Name of the subnet')
param subnetName string

@description('Ip adress range for the subnet')
param addressPrefix string

@description('Name of the parent vNet where the subnet will be created.')
param parentVnetName string

resource existingParentVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: parentVnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: subnetName
  parent: existingParentVnet
  properties: {
    addressPrefix: addressPrefix
  }
}

output subnetId string = subnet.id
