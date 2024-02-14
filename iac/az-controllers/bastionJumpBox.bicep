@description('Name for the Virtual Network')
param virtualNetworkName string = 'djn-s-dmo-vnet001'

@description('Name for the Public IP Address resource')
param publicIpAddressName string = 'djn-s-dmo-pip001'

@description('Name for the Bastion Host resource')
param bastionHostName string = 'djn-s-dmo-bas001'

@description('Name for the Network Interface Card resource')
param nicName string = 'djn-s-dmo-vm001-nic001'

@description('Name for the Virtual Machine resource - hopVM')
param hopVmName string = 'djn-s-dmo-vm001'

@description('Region in which the vNet should be deployed')
param resourceLocation string = resourceGroup().location

@description('Name of the subnet for the Azure Bastion Service')
param bastionSubnetName string = 'AzureBastionSubnet'

@description('Name of the hopVM subnet')
param hopVmSubnetName string = 'djn-s-dmo-snet001'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2as_v2'

@description('Name of the application subnet')
param applicationSubnetName string = 'djn-s-dmo-snet002'

@description('Admin username for the virtual machine')
param vmAdminUsername string

@description('Admin password for the virtual machine')
@secure()
param vmAdminPassword string

// Deployment name variables
var deploymentNames = {
  smallvNet: 'bastionJumpBox-small-vnet-module'
  standardPublicIp: 'bastionJumpBox-standard-public-ip-module'
  standardHost: 'bastionJumpBox-standard-bastion-host-module'
  simpleNic: 'bastionJumpBox-simple-nic-module'
  simpleVm: 'bastionJumpBox-simple-vm-module'
}

module smallvNet '../az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep' = {
  name: deploymentNames.smallvNet
  params: {
    virtualNetworkName: virtualNetworkName
    location: resourceLocation
    firstSubnetName: bastionSubnetName
    secondSubnetName: hopVmSubnetName
    thirdSubnetName: applicationSubnetName
  }
}

module bastionPublicIp '../az-modules/Microsoft.Network/publicIPAddresses/standardPip.bicep' = {
  name: deploymentNames.standardPublicIp
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
    subnetId: smallvNet.outputs.bastionSubnetId
    publicIpId: bastionPublicIp.outputs.publicIpAddressId
  }
}

module simpleNic '../az-modules/Microsoft.Network/networkInterfaces/simpleNic.bicep' = {
  name: deploymentNames.simpleNic
  dependsOn: [
    smallvNet
  ]
  params: {
    nicName: nicName
    location: resourceLocation
    subnetId: smallvNet.outputs.hopVmSubnetId

  }
}

module simpleVm '../az-modules/Microsoft.Compute/virtualMachines/jumpBoxVm.bicep' = {
  name: deploymentNames.simpleVm
  dependsOn: [
    smallvNet
    simpleNic
  ]
  params: {
    vmName: hopVmName
    location: resourceLocation
    vmSize: vmSize
    nicId: simpleNic.outputs.nicId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
  }
}
