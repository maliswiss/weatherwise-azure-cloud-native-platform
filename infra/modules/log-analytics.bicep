// =============================================================================
// Modul: Log Analytics Workspace + Application Insights
// =============================================================================
// Erfüllt K10 (Komplexität): Monitoring und Logging
// =============================================================================

@description('Name des Log Analytics Workspace')
param name string

@description('Name der Application Insights Instanz')
param appInsightsName string

@description('Azure-Region')
param location string

@description('Tags')
param tags object

// -----------------------------------------------------------------------------
// Log Analytics Workspace
// -----------------------------------------------------------------------------
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1  // Kostenkontrolle für $100 Credit
    }
  }
}

// -----------------------------------------------------------------------------
// Application Insights
// -----------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output workspaceId string = logAnalyticsWorkspace.id
output customerId string = logAnalyticsWorkspace.properties.customerId

@secure()
output primarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

output appInsightsId string = appInsights.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
