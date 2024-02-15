@description('Name for the Virtual Network')
param virtualNetworkName string

@description('Name for the Public IP Address resource')
param publicIpAddressName string

@description('Name for the Bastion Host resource')
param bastionHostName string

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
  smallvNet: 'bastionJumpBox-small-vnet-module'
  bastionSubnet: 'bastionJumpBox-bastion-subnet-module'
  jumpBoxSubnet: 'bastionJumpBox-jumpbox-subnet-module'
  standardPublicIp: 'bastionJumpBox-standard-public-ip-module'
  standardHost: 'bastionJumpBox-standard-bastion-host-module'
  jumpBoxNic: 'bastionJumpBox-simple-nic-module'
  jumpBoxVm: 'bastionJumpBox-jumpbox-vm-module'
  standardKeyVault: 'bastionJumpBox-standard-key-vault-module'
  usernameSecret: 'bastionJumpBox-standard-key-vault-username-module'
  passwordSecret: 'bastionJumpBox-standard-key-vault-password-module'
}

module smallvNet '../az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep' = {
  name: deploymentNames.smallvNet
  params: {
    virtualNetworkName: virtualNetworkName
    location: resourceLocation
  }
}

module bastionSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.bastionSubnet
  dependsOn: [
    smallvNet
  ]
  params: {
    subnetName: 'AzureBastionSubnet'
    addressPrefix: '10.0.1.0/25'
    parentVnetName: virtualNetworkName
  }
}

module jumpBoxSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.jumpBoxSubnet
  dependsOn: [
    smallvNet
  ]
  params: {
    subnetName: jumpBoxVmSubnetName
    addressPrefix: '10.0.2.0/25'
    parentVnetName: virtualNetworkName
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
    subnetId: jumpBoxSubnet.outputs.subnetId
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

module jumpBoxUserName '../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep' = {
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

module jumpBoxPassword '../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep' = {
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
