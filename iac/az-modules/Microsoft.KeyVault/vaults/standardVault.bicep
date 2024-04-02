metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: ''''This module deploys an Azure KeyVault using the standard SKU.
  It grants full data plane access to a specified user/service principal.'''''
}

@maxLength(24)
@description('KeyVault name.')
param keyVaultName string

@maxLength(128)
@description('KeyVault location.')
param location string

@description('Object ID of the user/service principal to grant full data plane access to the KeyVault.')
param principalObjectId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableSoftDelete: false
    accessPolicies: [
      {
        objectId: principalObjectId
        tenantId: tenant().tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}
