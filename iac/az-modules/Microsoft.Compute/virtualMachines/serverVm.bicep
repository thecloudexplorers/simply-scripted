metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This module deploys a server type Windows 2022 virtual machine.'
}>>>> master
}

@description('Name of the virtual machine resource')
param vmName string = 'djn-s-dmo-vm002'

@description('Location for all resources.')
param location string = 'West Europe'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2as_v2'

@description('Resoruce if of the network interface card')
param nicId string

@description('Admin username for the virtual machine')
param adminUsername string

@description('Admin password for the virtual machine')
@secure()
param adminPassword string

@description('Name of the Entra ID intergration extension')
var aadLoginExtensionName = 'AADLoginForWindows'

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk001'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
      dataDisks: [
        {
          name: '${vmName}-disk001'
          diskSizeGB: 50
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

resource vmAadLoginExtensionName 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: aadLoginExtensionName
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: aadLoginExtensionName
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}
