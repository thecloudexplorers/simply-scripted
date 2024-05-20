metadata moduleMetadata = {
  author: 'Jev Suchoi'
  description: 'This module deploys a blob service into an existing storage account.'
  version: '1.0.0'
}

@description('Name of the parent storage account where the blob services will be created.')
param parentStorageAccountName string

resource existingParentStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: parentStorageAccountName
}

resource storageAccountName_default 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: existingParentStorageAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
  }
}
