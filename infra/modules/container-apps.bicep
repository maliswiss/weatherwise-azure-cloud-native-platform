// =============================================================================
// Modul: Container Apps Environment + 3 Container Apps
// =============================================================================
// Erfüllt:
//   - K1 (Containerisierung): Multi-Service Container-Setup
//   - K3 (Secrets): Managed Identity + Key Vault Integration
//   - K4 (Deployment): HTTPS automatisch, Healthcheck-gesteuertes Rollout
//   - K8 (Security): Non-Root, Network-Isolation, Managed Identity
//   - K10 (Komplexität): Multi-Service, Rolling Deployment, Monitoring
// =============================================================================

@description('Azure-Region')
param location string

@description('Tags')
param tags object

@description('Umgebung (dev/prod)')
param environmentName string

@description('Container Apps Environment Name')
param containerAppEnvName string

@description('Backend App Name')
param backendAppName string

@description('Frontend App Name')
param frontendAppName string

@description('Redis App Name')
param redisAppName string

@description('Container Registry Name')
param acrName string

@description('Backend Image Tag')
param backendImageTag string

@description('Frontend Image Tag')
param frontendImageTag string

@description('Backend CPU (vCPU)')
param backendCpu string

@description('Backend Memory')
param backendMemory string

@description('Frontend CPU (vCPU)')
param frontendCpu string

@description('Frontend Memory')
param frontendMemory string

@description('Minimale Replikate')
param minReplicas int

@description('Maximale Replikate')
param maxReplicas int

@description('Key Vault Name')
param keyVaultName string

@description('Key Vault Secret URI für OpenWeather API-Key')
param keyVaultSecretUri string

@description('Log Analytics Workspace Customer ID')
param logAnalyticsCustomerId string

@description('Log Analytics Shared Key')
@secure()
param logAnalyticsSharedKey string

@description('Application Insights Connection String')
param appInsightsConnectionString string

// -----------------------------------------------------------------------------
// Existing Resources
// -----------------------------------------------------------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

// -----------------------------------------------------------------------------
// Container Apps Environment
// -----------------------------------------------------------------------------
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    zoneRedundant: false  // Single-Zone für Kostenoptimierung
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Managed Identity für Backend (Key Vault Zugriff)
// -----------------------------------------------------------------------------
resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${backendAppName}-identity'
  location: location
  tags: tags
}

// -----------------------------------------------------------------------------
// RBAC: Backend-Identity bekommt Key Vault Secrets User Rolle
// -----------------------------------------------------------------------------
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, backendIdentity.id, 'Key Vault Secrets User')
  properties: {
    principalId: backendIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    // Built-in Rolle "Key Vault Secrets User"
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
  }
}

// -----------------------------------------------------------------------------
// RBAC: Backend-Identity bekommt ACR Pull Rolle
// -----------------------------------------------------------------------------
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, backendIdentity.id, 'AcrPull')
  properties: {
    principalId: backendIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    // Built-in Rolle "AcrPull"
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
}

// -----------------------------------------------------------------------------
// Redis - Internal Service (nicht von außen erreichbar)
// -----------------------------------------------------------------------------
resource redisApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: redisAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false  // NUR intern erreichbar
        targetPort: 6379
        exposedPort: 6379
        transport: 'tcp'
      }
    }
    template: {
      containers: [
        {
          name: 'redis'
          image: 'redis:7-alpine'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          args: [
            '--maxmemory'
            '128mb'
            '--maxmemory-policy'
            'allkeys-lru'
            '--save'
            ''
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1  // Redis: Single Instance (kein Clustering)
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Backend Container App
// -----------------------------------------------------------------------------
resource backendApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: backendAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${backendIdentity.id}': {}
    }
  }
  dependsOn: [
    keyVaultSecretsUserRole
    acrPullRole
  ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        allowInsecure: false  // HTTPS only
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        corsPolicy: {
          allowedOrigins: ['*']  // Frontend URL wird vom Backend selbst gefiltert
          allowedMethods: ['GET']
          allowedHeaders: ['*']
        }
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: backendIdentity.id
        }
      ]
      secrets: [
        {
          name: 'openweather-api-key'
          keyVaultUrl: keyVaultSecretUri
          identity: backendIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: '${acrName}.azurecr.io/weatherwise-backend:${backendImageTag}'
          resources: {
            cpu: json(backendCpu)
            memory: backendMemory
          }
          env: [
            {
              name: 'OPENWEATHER_API_KEY'
              secretRef: 'openweather-api-key'
            }
            {
              name: 'REDIS_URL'
              value: 'redis://${redisAppName}:6379/0'
            }
            {
              name: 'CACHE_TTL_SECONDS'
              value: '600'
            }
            {
              name: 'APP_ENV'
              value: environmentName
            }
            {
              name: 'CORS_ORIGINS'
              value: '*'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 10
              periodSeconds: 30
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
        ]
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Frontend Container App
// -----------------------------------------------------------------------------
resource frontendApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: frontendAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${backendIdentity.id}': {}
    }
  }
  dependsOn: [
    acrPullRole
    backendApp
  ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false  // HTTPS only
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: backendIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: '${acrName}.azurecr.io/weatherwise-frontend:${frontendImageTag}'
          resources: {
            cpu: json(frontendCpu)
            memory: frontendMemory
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 3
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output containerAppEnvId string = containerAppEnv.id
output backendFqdn string = backendApp.properties.configuration.ingress.fqdn
output frontendFqdn string = frontendApp.properties.configuration.ingress.fqdn
output redisFqdn string = redisApp.properties.configuration.ingress.fqdn
output backendIdentityClientId string = backendIdentity.properties.clientId
output backendIdentityPrincipalId string = backendIdentity.properties.principalId
