targetScope = 'resourceGroup'


@allowed(['poc', 'test', 'stage', 'prod'])
param environment string

@description('Resource tags')
param tags object = {
  environment: environment
  project: 'portfolio'
}


@description('Email addresses for warning alerts')
param warningAlertEmails array


resource warningActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${environment}-warning-alerts'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Warning'
    enabled: true
    emailReceivers: [for (email, index) in warningAlertEmails: {
      name: 'Warning-Email-${index}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
  }
}


@description('Warning Action Group Resource ID')
output warningActionGroupId string = warningActionGroup.id

