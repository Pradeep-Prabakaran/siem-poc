targetScope = 'resourceGroup'

@description('Location for all resources')
param location string

@allowed(['poc', 'test', 'stage', 'prod'])
param environment string

@description('Resource tags')
param tags object = {
  environment: environment
  project: 'portfolio'
}
@description('Log Analytics Workspace Resource ID')
param lawWorkspaceId string

@description('Name for Application Insights component')
param appInsightsName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: lawWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsId string = appInsights.id
output appInsightsAppId string = appInsights.properties.AppId
output appInsightsName string = appInsights.name
