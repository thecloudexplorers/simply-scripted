param location string = resourceGroup().location
param definitionName string
param devcenterName string

resource existingDevCenter 'Microsoft.DevCenter/devcenters@2023-04-01' existing = {
  name: devcenterName
}

resource existingDevCenterGallery 'Microsoft.DevCenter/devcenters/galleries@2023-04-01' existing = {
  name: 'Default'
  parent: existingDevCenter
}

resource existingVisualStudioGalleryImage 'Microsoft.DevCenter/devcenters/galleries/images@2023-04-01' existing = {
  name: 'microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2'
  parent: existingDevCenterGallery
}

resource devboxdef 'Microsoft.DevCenter/devcenters/devboxdefinitions@2023-04-01' = {
  name: definitionName
  parent: existingDevCenter
  location: location
  properties: {
    sku: {
      name: 'general_i_8c32gb256ssd_v2'
    }
    imageReference: {
      id: existingVisualStudioGalleryImage.id //the resource-id of a Microsoft.DevCenter Gallery Image
    }
    osStorageType: 'ssd_256gb'
    hibernateSupport: 'Disabled'
  }
}
output definitionName string = devboxdef.name
output imageGalleryId string = existingVisualStudioGalleryImage.id
