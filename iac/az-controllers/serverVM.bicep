metadata controllerMetadata = {
  author: 'Jev Suchoi'
  description: '''This controller is used to deploy a virtual network, subnet, network interface card,
  and virtual machine in Azure.'''
  version: '1.0.0'
}

@description('Name for the Virtual Network')
param virtualNetworkName string

@description('Name of the server subnet')
param serverVmSubnetName string

@description('Name for the Network Interface Card resource')
param serverVmNicName string

@description('Name for the Virtual Machine resource - ServerVm')
param serverVmName string

@description('Region in which the vNet should be deployed')
param resourceLocation string

@description('Size of the virtual machine.')
param vmSize string

@description('Admin username for the virtual machine')
param vmAdminUsername string

@description('Admin password for the virtual machine')
@secure()
param vmAdminPassword string

// Deployment name variables
var deploymentNames = {
  serverSubnet: 'bastionJumpBox-jumpbox-subnet-module'
  serverNic: 'bastionJumpBox-server-nic-module'
  serverVm: 'bastionJumpBox-server-vm-module'
}

module serverSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: deploymentNames.serverSubnet
  params: {
    subnetName: serverVmSubnetName
    addressPrefix: '10.0.3.0/25'
    parentVnetName: virtualNetworkName
  }
}

module serverNic '../az-modules/Microsoft.Network/networkInterfaces/simpleNic.bicep' = {
  dependsOn: [
    serverSubnet
  ]
  name: deploymentNames.serverNic
  params: {
    nicName: serverVmNicName
    location: resourceLocation
    subnetId: serverSubnet.outputs.subnetId

  }
}

module serverVm '../az-modules/Microsoft.Compute/virtualMachines/serverVm.bicep' = {
  name: deploymentNames.serverVm
  dependsOn: [
    serverNic
  ]
  params: {
    vmName: serverVmName
    location: resourceLocation
    vmSize: vmSize
    nicId: serverNic.outputs.nicId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
  }
}
