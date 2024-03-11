metadata moduleMetadata = {
  author: 'Jev Suchoi'
  description: 'This module deploys an Azure Container Registry (ACR) using the Basic SKU.'
  version: '1.0.0'
}

@minLength(5)
@maxLength(50)
@description('Name of the azure container registry (must be globally unique)')
param acrName string = 'djnsdmocr001'

@description('Location for the azure container registry. Defaults to the location of the resource group.')
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}
