metadata controllerMetadata = {
  author: 'Jev Suchoi'
  description: '''TODO'''
  version: '1.0.0'
}

@description('TODO')
param storageAccountNameDev string

@description('TODO')
param storageAccountNamePrd string

@description('''
TODO
''')
@allowed([
  'new'
  'existing'
])
param newOrExistingVirtualNetwork string = 'existing'

@description('Name for the Virtual Network')
param virtualNetworkName string

@description('Address prefix for the jumpBoxVmSubnet')
param jumpBoxVmSubnetAddressPrefixDev string

@description('Address prefix for the jumpBoxVmSubnet')
param jumpBoxVmSubnetAddressPrefixPrd string

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

@description('TODO')
param jumpBoxVmSubnetNameDev string

@description('TODO')
param jumpBoxVmSubnetNamePrd string

@description('Admin username for the virtual machine')
param vmAdminUsername string

@description('Admin password for the virtual machine')
@secure()
param vmAdminPassword string

@description('Object ID of the user/service principal to grant full data plane access to the KeyVault.')
param principalObjectId string

// Deployment name variables
var deploymentNames = {
  storageAccountDev: 'storageAccountDev-module'
  storageAccountPrd: 'storageAccountPrd-module'
  storageBlobDev: 'storageBlobDev-module'
  storageBlobPrd: 'storageBlobPrd-module'
  bastionNsg: 'bastionJumpBox-bastion-nsg-module'
  jumpBoxVmNsg: 'bastionJumpBox-jumpboxvm-nsg-module'
  smallvNet: 'bastionJumpBox-small-vnet-module'
  jumpBoxVmSubnetDev: 'bastionJumpBoxDev-jumpboxvm-subnet-module'
  jumpBoxVmSubnetPrd: 'bastionJumpBoxPrd-jumpboxvm-subnet-module'
  standardPublicIp: 'bastionJumpBox-standard-public-ip-module'
  standardHost: 'bastionJumpBox-standard-bastion-host-module'
  jumpBoxNic: 'bastionJumpBox-simple-nic-module'
  jumpBoxVm: 'bastionJumpBox-jumpbox-vm-module'
  standardKeyVault: 'bastionJumpBox-standard-key-vault-module'
  usernameSecret: 'bastionJumpBox-standard-key-vault-username-module'
  passwordSecret: 'bastionJumpBox-standard-key-vault-password-module'
}

module standardStorageDev '../az-modules/Microsoft.Storage/storageAccounts/standardStorageAccount.bicep' = {
  name: deploymentNames.storageAccountDev
  params: {
    storageAccountName: storageAccountNameDev
    location: resourceLocation
  }
}

module standardStoragePrd '../az-modules/Microsoft.Storage/storageAccounts/standardStorageAccount.bicep' = {
  name: deploymentNames.storageAccountPrd
  params: {
    storageAccountName: storageAccountNamePrd
    location: resourceLocation
  }
}

module standardBlobStorageDev '../az-modules/Microsoft.Storage/storageAccounts/blobServices/standardBlobService.bicep' = {
  name: deploymentNames.storageBlobDev
  dependsOn: [
    standardStorageDev
  ]
  params: {
    parentStorageAccountName: storageAccountNameDev
  }
}

module standardBlobStoragePrd '../az-modules/Microsoft.Storage/storageAccounts/blobServices/standardBlobService.bicep' = {
  name: deploymentNames.storageBlobPrd
  dependsOn: [
    standardStoragePrd
  ]
  params: {
    parentStorageAccountName: storageAccountNamePrd
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

module jumpBoxVmSubnetDev '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.jumpBoxVmSubnetDev
  dependsOn: [
    smallvNet
  ]
  params: {
    subnetName: jumpBoxVmSubnetNameDev
    addressPrefix: jumpBoxVmSubnetAddressPrefixDev
    parentVnetName: virtualNetworkName
  }
}

module jumpBoxVmSubnetPrd '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.jumpBoxVmSubnetPrd
  dependsOn: [
    smallvNet
    jumpBoxVmSubnetDev
  ]
  params: {
    subnetName: jumpBoxVmSubnetNamePrd
    addressPrefix: jumpBoxVmSubnetAddressPrefixPrd
    parentVnetName: virtualNetworkName
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
    subnetId: jumpBoxVmSubnetDev.outputs.subnetId
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
