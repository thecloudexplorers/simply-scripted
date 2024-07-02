metadata controllerMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: '''This controller deploys a virtual network with two subnets, a bastion host, a jumpbox VM, and a key vault.
  It also creates a secret in the key vault for the jumpbox VM username and password. The jumpbox VM is deployed with the
  specified username and password. The key vault is granted full data plane access to the specified user/service principal.
  The virtual network is deployed with the specified address prefixes. The bastion host is deployed with the specified public
  IP address name. The bastion host and jumpbox VM are deployed with the specified network security group names. The jumpbox
  VM is deployed with the specified virtual machine size. The jumpbox VM is deployed with the specified subnet name. The jumpbox
  VM is deployed with the specified admin username and password. The virtual network, bastion host, jumpbox VM, and key vault
  are deployed in the specified region.'''
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
param newOrExistingVirtualNetwork string = 'existing'

@description('Name for the Virtual Network')
param virtualNetworkName string

@description('Address prefix for the AzureBastionSubnet')
param bastionSubnetAddressPrefix string = '10.0.1.0/25'

@description('Address prefix for the jumpBoxVmSubnet')
param jumpBoxVmSubnetAddressPrefix string = '10.0.2.0/25'

@description('Name for the Public IP Address resource of the Bastion Host')
param publicIpAddressName string

@description('Name for the Bastion Host resource')
param bastionHostName string

@description('Name for the bastion NSG resource')
param bastionNsgName string = 'djn-s-dmo-nsg001'

@description('Name for the jumpBoxVmNsgName NSG resource')
param jumpBoxVmNsgName string = 'djn-s-dmo-nsg002'

@description('Name for the Virtual Machine resource - hopVm')
param jumpBoxVmName string

@description('Name for the Network Interface Card resource')
param jumpBoxVmNicName string

@description('Name for the Key Vault resource')
param keyVaultName string

@description('Region in which the vNet should be deployed')
param resourceLocation string

@description('Size of the virtual machine.')
param vmSize string

@description('Name of the hopVM subnet')
param jumpBoxVmSubnetName string

@description('Admin username for the virtual machine')
param vmAdminUsername string

@description('Admin password for the virtual machine')
@secure()
param vmAdminPassword string

@description('Object ID of the user/service principal to grant full data plane access to the KeyVault.')
param principalObjectId string

// Deployment name variables
var deploymentNames = {
  bastionNsg: 'bastionJumpBox-bastion-nsg-module'
  jumpBoxVmNsg: 'bastionJumpBox-jumpboxvm-nsg-module'
  smallvNet: 'bastionJumpBox-small-vnet-module'
  bastionSubnet: 'bastionJumpBox-bastion-subnet-module'
  jumpBoxVmSubnet: 'bastionJumpBox-jumpboxvm-subnet-module'
  standardPublicIp: 'bastionJumpBox-standard-public-ip-module'
  standardHost: 'bastionJumpBox-standard-bastion-host-module'
  jumpBoxNic: 'bastionJumpBox-simple-nic-module'
  jumpBoxVm: 'bastionJumpBox-jumpbox-vm-module'
  standardKeyVault: 'bastionJumpBox-standard-key-vault-module'
  usernameSecret: 'bastionJumpBox-standard-key-vault-username-module'
  passwordSecret: 'bastionJumpBox-standard-key-vault-password-module'
}

module bastionNsg '../az-modules/Microsoft.Network/networkSecurityGroups/bastionNsg.bicep' = {
  name: deploymentNames.bastionNsg
  params: {
    networkSecurityGroupName: bastionNsgName
    location: resourceLocation
  }
}

module jumpBoxVmNsg '../az-modules/Microsoft.Network/networkSecurityGroups/jumpVmNsg.bicep' = {
  name: deploymentNames.jumpBoxVmNsg
  params: {
    networkSecurityGroupName: jumpBoxVmNsgName
    location: resourceLocation
  }
}
module smallvNet '../az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep' = {
  name: deploymentNames.smallvNet
  params: {
    newOrExisting: newOrExistingVirtualNetwork
    virtualNetworkName: virtualNetworkName
    location: resourceLocation
  }
}

module bastionSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.bastionSubnet
  dependsOn: [
    bastionNsg
    jumpBoxVmNsg
    smallvNet
  ]
  params: {
    subnetName: 'AzureBastionSubnet'
    addressPrefix: bastionSubnetAddressPrefix
    parentVnetName: virtualNetworkName
    nsgId: bastionNsg.outputs.nsgId
  }
}

module jumpBoxVmSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.jumpBoxVmSubnet
  dependsOn: [
    bastionNsg
    jumpBoxVmNsg
    smallvNet
  ]
  params: {
    subnetName: jumpBoxVmSubnetName
    addressPrefix: jumpBoxVmSubnetAddressPrefix
    parentVnetName: virtualNetworkName
    nsgId: jumpBoxVmNsg.outputs.nsgId
  }
}

module bastionPublicIp '../az-modules/Microsoft.Network/publicIPAddresses/standardPip.bicep' = {
  name: deploymentNames.standardPublicIp
  dependsOn: [
    smallvNet
  ]
  params: {
    publicIpAddressName: publicIpAddressName
    location: resourceLocation
  }
}

module basicBastionHost '../az-modules/Microsoft.Network/bastionHosts/basicBastionHost.bicep' = {
  name: deploymentNames.standardHost
  dependsOn: [
    smallvNet
    bastionPublicIp
    bastionNsg
    jumpBoxVmNsg
  ]
  params: {
    bastionHostName: bastionHostName
    location: resourceLocation
    subnetId: bastionSubnet.outputs.subnetId
    publicIpId: bastionPublicIp.outputs.publicIpAddressId
  }
}

module jumpBoxNic '../az-modules/Microsoft.Network/networkInterfaces/simpleNic.bicep' = {
  name: deploymentNames.jumpBoxNic
  dependsOn: [
    smallvNet
  ]
  params: {
    nicName: jumpBoxVmNicName
    location: resourceLocation
    subnetId: jumpBoxVmSubnet.outputs.subnetId
  }
}

module jumpBoxVm '../az-modules/Microsoft.Compute/virtualMachines/jumpBoxVm.bicep' = {
  name: deploymentNames.jumpBoxVm
  dependsOn: [
    smallvNet
    jumpBoxNic
  ]
  params: {
    vmName: jumpBoxVmName
    location: resourceLocation
    vmSize: vmSize
    nicId: jumpBoxNic.outputs.nicId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
  }
}
module standardKeyVault '../az-modules/Microsoft.KeyVault/vaults/standardVault.bicep' = {
  name: deploymentNames.standardKeyVault
  params: {
    keyVaultName: keyVaultName
    location: resourceLocation
    principalObjectId: principalObjectId
  }
}

module jumpVmUserName '../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep' = {
  dependsOn: [
    standardKeyVault
  ]
  name: deploymentNames.usernameSecret
  params: {
    parentKeyVaultName: keyVaultName
    secretName: 'jumpboxVmUsername'
    secretValue: vmAdminUsername
  }
}

module jumpVmPassword '../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep' = {
  dependsOn: [
    standardKeyVault
  ]
  name: deploymentNames.passwordSecret
  params: {
    parentKeyVaultName: keyVaultName
    secretName: 'jumpboxVmPassword'
    secretValue: vmAdminPassword
  }
}
