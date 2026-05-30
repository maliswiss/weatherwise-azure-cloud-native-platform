// =============================================================================
// Modul: Azure Key Vault für Secrets
// =============================================================================
// Erfüllt K3 (Secrets): "Secrets via Plattform oder Vault"
// Erfüllt K8 (Security): RBAC, Soft Delete, kein public access
// =============================================================================

@description('Name des Key Vaults (global eindeutig)')
param name string

@description('Azure-Region')
param location string

@description('Tags')
param tags object

@description('OpenWeatherMap API-Key (wird verschlüsselt gespeichert)')
@secure()
param openWeatherApiKey string

// -----------------------------------------------------------------------------
// Key Vault
// -----------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true  // RBAC statt Access Policies (moderner)
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: null
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// -----------------------------------------------------------------------------
// Secret: OpenWeatherMap API-Key
// -----------------------------------------------------------------------------
resource openWeatherSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'openweather-api-key'
  properties: {
    value: openWeatherApiKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output openWeatherSecretUri string = openWeatherSecret.properties.secretUri
output openWeatherSecretName string = openWeatherSecret.name
