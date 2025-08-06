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

@description('Virtual Network name')
param vnetName string = '${environment}-vnet'

@description('Application subnet name')
param appSubnetName string

@description('Private endpoint subnet name')
param privateEndpointSubnetName string

@description('Application NSG name')
param appNsgName string = '${environment}-app-nsg'

@description('Bastion NSG name')
param bastionNsgName string = '${environment}-bastion-nsg'

param natGatewayId string

@description('Log Analytics Workspace Resource ID')
param lawWorkspaceId string

var vnetAddressSpace = '10.0.0.0/16'
var bastionSubnetAddressSpace = '10.0.1.0/27'
var privateEndpointSubnetAddressSpace = '10.0.2.0/24'
var appSubnetAddressSpace = '10.0.3.0/24'

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: appNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSHFromBastion'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetAddressSpace
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: bastionNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389']
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}


resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetAddressSpace
          networkSecurityGroup: {
            id: appNsg.id
          }
          natGateway: {
            id: natGatewayId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressSpace
          networkSecurityGroup: {
            id: bastionNsg.id
          }
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetAddressSpace
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource appNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environment}-app-nsg-diagnostics'
  scope: appNsg
  properties: {
    workspaceId: lawWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// BASTION NSG DIAGNOSTIC SETTINGS
// =============================================================================

resource bastionNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environment}-bastion-nsg-diagnostics'
  scope: bastionNsg
  properties: {
    workspaceId: lawWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

@description('Virtual Network Resource ID')
output vnetId string = vnet.id

@description('Application Subnet Resource ID')
output appSubnetId string = vnet.properties.subnets[0].id

@description('Bastion Subnet Resource ID')
output bastionSubnetId string = vnet.properties.subnets[1].id

@description('Private Endpoint Subnet Resource ID')
output privateEndpointSubnetId string = vnet.properties.subnets[2].id

@description('Application NSG Resource ID')
output appNsgId string = appNsg.id

@description('Bastion NSG Resource ID')
output bastionNsgId string = bastionNsg.id
