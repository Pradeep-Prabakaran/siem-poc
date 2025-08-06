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

@description('NAT Gateway name')
param natGatewayName string

@description('NAT Gateway Public IP name')
param natGatewayPipName string

@description('Log Analytics Workspace Resource ID')
param lawWorkspaceId string

resource natGatewayPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: natGatewayPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  zones: ['1', '2', '3']
}

// =============================================================================
// NAT GATEWAY
// =============================================================================

resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: natGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natGatewayPip.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
  zones: ['1']
}

resource natGatewayDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environment}-nat-diagnostics'
  scope: natGateway
  properties: {
    workspaceId: lawWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


output natGatewayId string = natGateway.id
