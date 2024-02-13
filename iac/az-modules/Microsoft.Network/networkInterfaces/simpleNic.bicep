@description('Name of the Nic resource')
param nicName string = 'djn-s-dmo-nic001'

@description('Region in which the Nic should be deployed')
param location string = 'West Europe'

@description('Id of the subnet to which the Nic should be connected')
param subnetId string

resource simpleNic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'

          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

output nicId string = simpleNic.id
