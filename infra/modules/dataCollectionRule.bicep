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

@description('VM Scale Set Resource ID')
param vmssName string

param dcrName string

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2021-04-01' = {
  name: dcrName
  location: location
  tags: tags
  kind: 'Linux'
  properties: {
    description: 'DCR for VMSS Azure Monitor Agent'
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounters'
          streams: [ 'Microsoft-Perf' ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
                        'Processor(*)\\% Processor Time'
                        'Processor(*)\\% Idle Time'
                        'Processor(*)\\% User Time'
                        'Processor(*)\\% Nice Time'
                        'Processor(*)\\% Privileged Time'
                        'Processor(*)\\% IO Wait Time'
                        'Processor(*)\\% Interrupt Time'
                        'Memory(*)\\Available MBytes Memory'
                        'Memory(*)\\% Available Memory'
                        'Memory(*)\\Used Memory MBytes'
                        'Memory(*)\\% Used Memory'
                        'Memory(*)\\Pages/sec'
                        'Memory(*)\\Page Reads/sec'
                        'Memory(*)\\Page Writes/sec'
                        'Memory(*)\\Available MBytes Swap'
                        'Memory(*)\\% Available Swap Space'
                        'Memory(*)\\Used MBytes Swap Space'
                        'Memory(*)\\% Used Swap Space'
                        'Process(*)\\Pct User Time'
                        'Process(*)\\Pct Privileged Time'
                        'Process(*)\\Used Memory'
                        'Process(*)\\Virtual Shared Memory'
                        'System(*)\\Uptime'
                        'System(*)\\Load1'
                        'System(*)\\Load5'
                        'System(*)\\Load15'
                        'System(*)\\Users'
                        'System(*)\\Unique Users'
                        'System(*)\\CPUs'
                        '\\Processor(_Total)\\% Processor Time'
                        '\\Memory\\Available MBytes'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslog'
          streams: [ 'Microsoft-Syslog' ]
          facilityNames: [ '*' ]
          logLevels: [ 'Error', 'Warning', 'Critical' ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'law'
          workspaceResourceId: lawWorkspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [ 'Microsoft-Perf', 'Microsoft-Syslog' ]
        destinations: [ 'law' ]
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-07-01' existing = {
  name: vmssName
  scope: resourceGroup()  
}

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: 'dcr-vmss-assoc'
  scope: vmss
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
  }
}

output dcrId string = dataCollectionRule.id
output dcrAssocName string = dcrAssociation.name
