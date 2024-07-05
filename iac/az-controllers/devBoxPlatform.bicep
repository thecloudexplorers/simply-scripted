metadata controllerMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: '''TODO: Fill in the description'''
}

@description('Location for the resources')
param resourceLocation string = resourceGroup().location

@allowed([
  'new'
  'existing'
])
param newOrExistingVirtualNetwork string

@description('Name for the Virtual Network')
param virtualNetworkName string

@description('Address prefix for the DevBox subnetubnet')
param devBoxSubnetAddressPrefix string

@description('Name of the DevBox subnet')
param devBoxSubnetName string

@description('The name of the DevCenter')
param devCenterName string

@description('The name of the Project')
param projectName string

@description('Name for the Dev Center Network Connection')
param devCenterNetworkConnectionName string

@description('Name for the DevBox definition')
param devBoxDefinitionName string

@description('Name for the DevCenter Project Pool')
param devCenterProjectPoolName string

module smallvNet '../az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep' = {
  name: 'deploySmallvNet'
  params: {
    newOrExisting: newOrExistingVirtualNetwork
    virtualNetworkName: virtualNetworkName
    location: resourceLocation
  }
}

module devBoxVmSubnet '../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep' = {
  name: 'standardSubnet'
  dependsOn: [
    smallvNet
  ]
  params: {
    subnetName: devBoxSubnetName
    addressPrefix: devBoxSubnetAddressPrefix
    parentVnetName: virtualNetworkName
  }
}

module devCenter '../az-modules/Microsoft.DevCenter/devcenters/standardDevCenter.bicep' = {
  name: 'deployDevCenter'
  params: {
    location: resourceLocation
    devCenterName: devCenterName
  }
}

module devCenterProject '../az-modules/Microsoft.DevCenter/projects/standardProject.bicep' = {
  name: 'deployDevCenterProject'
  params: {
    location: resourceLocation
    projectName: projectName
    devCenterId: devCenter.outputs.devCenterResourceId
  }
}

module standardDevCenterNetworkConnection '../az-modules/Microsoft.DevCenter/networkConnections/standardNetworkConnection.bicep' = {
  name: 'standardNetworkConnection'
  params: {
    location: resourceLocation
    devCenterNetworkConnectionName: devCenterNetworkConnectionName
    subnetId: devBoxVmSubnet.outputs.subnetId
  }
}

resource existingDevCenter 'Microsoft.DevCenter/devcenters@2023-04-01' existing = {
  name: devCenterName
}

resource attachedNetwork 'Microsoft.DevCenter/devcenters/attachednetworks@2023-04-01' = {
  name: 'standardDevCenterAttachedNetworkConnection'
  parent: existingDevCenter
  properties: {
    networkConnectionId: standardDevCenterNetworkConnection.outputs.networkConnectionResourceId
  }
}

module devBoxDefinition '../az-modules/Microsoft.DevCenter/devcenters/devboxdefinitions/vs2022EntGeneralWin11M365Gen2.bicep' = {
  name: 'deployDevBoxDefinition'
  dependsOn: [
    devCenter
  ]
  params: {
    location: resourceLocation
    definitionName: devBoxDefinitionName
    devcenterName: devCenterName
  }
}

module devCenterProjectPool '../az-modules/Microsoft.DevCenter/projects/pools/standardPool.bicep' = {
  name: 'deployevCenterProjectPool'
  dependsOn: [
    devCenter
    devCenterProject
    attachedNetwork
  ]
  params: {
    location: resourceLocation
    projectPoolName: devCenterProjectPoolName
    parentDevCenterProjectName: projectName
    devBoxDefinitionName: devBoxDefinitionName
  }
}
