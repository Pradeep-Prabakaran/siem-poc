targetScope = 'resourceGroup'

@description('Location for all resources')
param location string

param environment string

@description('Resource tags')
param tags object

@description('VM Scale Set name')
param vmssName string

@description('Admin username')
param adminUsername string

@secure()
@description('SSH public key')
param sshPublicKey string

@description('VM SKU')
param vmSku string

@description('Minimum capacity')
param minCapacity int

@description('Maximum capacity')
param maxCapacity int

@description('CPU threshold for autoscaling')
param cpuThreshold int

@description('Application subnet ID')
param appSubnetId string

param backendPoolId string

@description('Managed Identity Resource ID')
param managedIdentityResourceId string

@description('Managed Identity Principal ID (GUID)')
param managedIdentityPrincipalId string

@description('The name of the Key Vault')
param kvName string

@description('The name of the App Insights connection string secret in Key Vault')
param appInsightsSecretName string = 'appinsights-connection-string'

var cloudInitScript = base64(replace(replace(loadTextContent('scripts/cloud-init.yaml'), '__KEY_VAULT_NAME__', kvName), '__SECRET_NAME__', appInsightsSecretName))

@description('Data Collection Rule name')
param dcrName string

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2021-04-01' existing = {
  name: dcrName
  scope: resourceGroup()
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: vmssName
  location: location
  tags: tags
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: minCapacity
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
  properties: {      
    orchestrationMode: 'Flexible'      
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 64
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: take(vmssName, 9)
        adminUsername: adminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
          patchSettings: {
           patchMode: 'AutomaticByPlatform'
}
        }
        customData: cloudInitScript
      }
      networkProfile: {
        networkApiVersion: '2022-11-01'
        networkInterfaceConfigurations: [
          {
            name: '${vmssName}-nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: '${vmssName}-ipconfig'
                  properties: {
                    subnet: {
                       id: appSubnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                         id: backendPoolId
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'ApplicationHealthExtension'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthLinux'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              settings: {
                protocol: 'http'
                port: 80
                requestPath: '/health'
              }
            }
          }
          {
            name: 'AzureMonitorLinuxAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitor'
              type: 'AzureMonitorLinuxAgent'
              typeHandlerVersion: '1.22'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                authentication: {
                  type: 'ManagedIdentity'
                  managedIdentityResourceId: managedIdentityResourceId
                }
              }
            }
          }
        ]
      }
    }
    platformFaultDomainCount: 1
  }
}

resource dcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataCollectionRule.id, 'monitoring-reader-assignment')
  scope: dataCollectionRule
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')  // Monitoring Reader
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${vmssName}-autoscale'
  location: location
  tags: tags
  properties: {
    profiles: [
      {
        name: 'DefaultProfile'
        capacity: {
          minimum: string(minCapacity)
          maximum: string(maxCapacity)
          default: string(minCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: cpuThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: cpuThreshold - 20
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: vmss.id
  }
}

resource vmMonitorAgent 'Microsoft.Compute/virtualMachineScaleSets/extensions@2023-09-01' = {
  parent: vmss
  name: 'AzureMonitorLinuxAgent'
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.22'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}

resource warningActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' existing = {
  name: '${environment}-warning-alerts'
  scope: resourceGroup()
    }

resource vmssHighCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${environment}-vmss-high-cpu'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when VMSS CPU percentage is greater than 35%'
    severity: 2
    enabled: true
    scopes: [vmss.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 35
          name: 'HighCPU'
          metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: warningActionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

@description('VM Scale Set Resource ID')
output vmssId string = vmss.id
