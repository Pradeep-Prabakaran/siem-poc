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

@description('The name of the Key Vault')
param kvName string = '${environment}-simpoc-kvault'

@description('Object ID of the user who needs admin access')
param objectId string

@description('Principal ID of the user-assigned managed identity')
param userAssignedIdentityPrincipalId string

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string

param vnetName string

@description('SSH Public Key')
@secure()
param sshPublicKey string


 @secure()
 @description('Base64-encoded PEM ca_cert')
 param ca_cert string                                

 @secure()
 @description('Base64-encoded PEM origin_cert')
 param origin_cert string                                 

 @secure()
 @description('Base64-encoded PEM cert key')
 param origin_key string 

 @description('Log Analytics Workspace Resource ID')
param lawWorkspaceId string

@description('Application Insights Connection String')
@secure()
param appInsightsConnectionString string


resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// RBAC Role Assignment: Key Vault Administrator for deployment user
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, objectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: objectId
    principalType: 'User'
  }
}

// RBAC Role Assignment: Key Vault Secrets User for managed identity
resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, userAssignedIdentityPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// KEY VAULT PRIVATE ENDPOINT
// =============================================================================

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${kvName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${kvName}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  name: 'default'
  parent: keyVaultPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyvault'
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${kvName}-vnet-link'
  parent: keyVaultPrivateDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', vnetName)
    }
  }
}

resource sshKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'vm-ssh-public-key'
  properties: {
    value: sshPublicKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// PEM Certificate #1
resource cert1Secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ca-cert'                                   // logical name
  properties: {
    value: ca_cert                                     // Base64 PEM #1
    contentType: 'application/x-pem-file'               // indicates PEM format
    attributes: { enabled: true }
  }
}

// PEM Certificate #2
resource cert2Secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'origin-cert'                                 // logical name
  properties: {
    value: origin_cert
    contentType: 'application/x-pem-file'
    attributes: { enabled: true }
  }
}

// PEM Private Key
resource keySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'origin-key'                                 // logical name
  properties: {
    value: origin_key                                      // Base64 PEM private key
    contentType: 'application/x-pem-file'
    attributes: { enabled: true }
  }
}

// Application Insights Connection String Secret
resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'appinsights-connection-string'
  properties: {
    value: appInsightsConnectionString
    contentType: 'application/connection-string'
    attributes: {
      enabled: true
    }
  }
}


resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environment}-kv-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: lawWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
