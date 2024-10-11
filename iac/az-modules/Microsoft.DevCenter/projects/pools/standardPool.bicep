param location string = resourceGroup().location

param projectPoolName string

param parentDevCenterProjectName string

param devBoxDefinitionName string

resource existingDevCenterProject 'Microsoft.DevCenter/projects@2023-04-01' existing = {
  name: parentDevCenterProjectName
}

resource devCenterProjectPool 'Microsoft.DevCenter/projects/pools@2024-05-01-preview' = {
  name: projectPoolName
  location: location
  parent: existingDevCenterProject
  properties: {
    devBoxDefinitionName: devBoxDefinitionName
    licenseType: 'Windows_Client'
    localAdministrator: 'Enabled'
    networkConnectionName: 'managedNetwork'
    virtualNetworkType: 'Managed'
    managedVirtualNetworkRegions: [
      'westeurope'
    ]
  }
}
