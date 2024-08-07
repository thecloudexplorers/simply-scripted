metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This module deploys a secret to an existing key vault.'
}

@description('Name of the secret')
param secretName string

@description('Value of the secret')
@secure()
param secretValue string

@description('Name of the parent key vault where the secret will be created.')
param parentKeyVaultName string

resource existingParentKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: parentKeyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: existingParentKeyVault
  name: secretName
  properties: {
    value: secretValue
  }
}
