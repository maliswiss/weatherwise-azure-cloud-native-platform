// =============================================================================
// WeatherWise - Hauptkonfiguration (Bicep IaC)
// =============================================================================
// Erfüllt Bewertungskriterien:
//   - K3 (Secrets): Azure Key Vault Integration
//   - K4 (Deployment): Azure Container Apps mit HTTPS + Healthchecks
//   - K8 (Security): Managed Identity, Non-Root, Key Vault
//   - K10 (Komplexität): Infrastructure as Code
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Parameter
// -----------------------------------------------------------------------------
@description('Umgebungs-Name: dev oder prod')
@allowed(['dev', 'prod'])
param environmentName string

@description('Azure-Region für alle Ressourcen')
param location string = resourceGroup().location

@description('Projekt-Präfix für alle Ressourcen-Namen')
param projectPrefix string = 'weatherwise'

@description('OpenWeatherMap API-Key - kommt aus GitHub Secrets')
@secure()
param openWeatherApiKey string

@description('Container-Image-Tag für Backend')
param backendImageTag string = 'latest'

@description('Container-Image-Tag für Frontend')
param frontendImageTag string = 'latest'

@description('Container-Registry-Name')
param acrName string

@description('CPU-Limit für Backend (vCPU)')
param backendCpu string = '0.5'

@description('Memory-Limit für Backend')
param backendMemory string = '1Gi'

@description('CPU-Limit für Frontend (vCPU)')
param frontendCpu string = '0.25'

@description('Memory-Limit für Frontend')
param frontendMemory string = '0.5Gi'

@description('Minimale Anzahl Replikate (0 für Scale-to-Zero)')
param minReplicas int = 1

@description('Maximale Anzahl Replikate')
param maxReplicas int = 3

// -----------------------------------------------------------------------------
// Variablen
// -----------------------------------------------------------------------------
var tags = {
  project: 'WeatherWise'
  environment: environmentName
  managedBy: 'Bicep'
  owner: 'Mehmet Ali Gür'
  module: 'HF Informatik - LB2 Deployment'
}

var keyVaultName = 'wwkv${environmentName}${take(uniqueString(resourceGroup().id), 10)}'
var logAnalyticsName = '${projectPrefix}-logs-${environmentName}'
var appInsightsName = '${projectPrefix}-insights-${environmentName}'
var containerAppEnvName = '${projectPrefix}-env-${environmentName}'
var backendAppName = '${projectPrefix}-backend-${environmentName}'
var frontendAppName = '${projectPrefix}-frontend-${environmentName}'
var redisAppName = '${projectPrefix}-redis-${environmentName}'

// -----------------------------------------------------------------------------
// Module: Log Analytics + Application Insights (Monitoring)
// -----------------------------------------------------------------------------
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    name: logAnalyticsName
    appInsightsName: appInsightsName
    location: location
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Module: Key Vault (Secrets)
// -----------------------------------------------------------------------------
module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-key-vault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    openWeatherApiKey: openWeatherApiKey
  }
}

// -----------------------------------------------------------------------------
// Module: Container Apps Environment + 3 Apps (Backend, Frontend, Redis)
// -----------------------------------------------------------------------------
module containerApps 'modules/container-apps.bicep' = {
  name: 'deploy-container-apps'
  params: {
    location: location
    tags: tags
    environmentName: environmentName
    containerAppEnvName: containerAppEnvName
    backendAppName: backendAppName
    frontendAppName: frontendAppName
    redisAppName: redisAppName
    acrName: acrName
    backendImageTag: backendImageTag
    frontendImageTag: frontendImageTag
    backendCpu: backendCpu
    backendMemory: backendMemory
    frontendCpu: frontendCpu
    frontendMemory: frontendMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    keyVaultName: keyVault.outputs.keyVaultName
    keyVaultSecretUri: keyVault.outputs.openWeatherSecretUri
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    logAnalyticsSharedKey: logAnalytics.outputs.primarySharedKey
    appInsightsConnectionString: logAnalytics.outputs.appInsightsConnectionString
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('FQDN des Frontends (mit HTTPS)')
output frontendUrl string = 'https://${containerApps.outputs.frontendFqdn}'

@description('FQDN des Backends (mit HTTPS)')
output backendUrl string = 'https://${containerApps.outputs.backendFqdn}'

@description('Name des Key Vaults')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Name der Container Apps Environment')
output containerAppEnvName string = containerAppEnvName

@description('Backend Container App Name')
output backendAppName string = backendAppName

@description('Frontend Container App Name')
output frontendAppName string = frontendAppName
