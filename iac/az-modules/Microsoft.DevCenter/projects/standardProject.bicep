@description('Location for the Project')
param location string = resourceGroup().location

@description('The name of the Project')
param projectName string

@description('The ID of the DevCenter')
param devCenterId string

resource project 'Microsoft.DevCenter/projects@2023-04-01' = {
  name: projectName
  location: location
  properties: {
    devCenterId: devCenterId
    // Add any additional properties required for your Project here
  }
}

output projectResourceId string = project.id
