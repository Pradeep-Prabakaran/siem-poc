// modules/availability-test.bicep

targetScope = 'resourceGroup'

param appInsightsId string
param location string
param appName string
param publicIpAddress string
param warningActionGroupId string
param tags object

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: '${appName}-availability-test'
  location: location
  tags: union(tags, {
    'hidden-link': appInsightsId
  })
  kind: 'ping'
  properties: {
    Frequency: 300
    Timeout: 120
    Enabled: true
    Locations: [
      {
        Id: 'azure:eastus'
      }
      {
        Id: 'azure:westeurope'
      }
      {
        Id: 'azure:southeastasia'
      }
    ]
    Configuration: {
      WebTest: '<WebTest Name="${appName}-availability-test" Id="" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="120" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">\n\t<Items>\n\t\t<Request Method="GET" Guid="" Version="1.1" Url="http://${publicIpAddress}" ThinkTime="0" Timeout="120" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />\n\t</Items>\n</WebTest>'
    }
  }
}

resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${appName}-availability-alert'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when the website is not available from at least two locations.'
    severity: 1
    enabled: true
    scopes: [
      appInsightsId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: availabilityTest.id
      componentId: appInsightsId
      failedLocationCount: 2
    }
    actions: [
      {
        actionGroupId: warningActionGroupId
      }
    ]
  }
}
