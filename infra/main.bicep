targetScope = 'subscription'

@description('Location for all resources')
param location string

@allowed(['poc', 'prod', 'test', 'stage'])
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

@description('The name of the resource group')
param rgName string = '${environment}-rg'

@description('Bastion name')
param bastionName string = '${environment}-bastion'

@description('Bastion Public IP name')
param bastionPipName string = '${environment}-bastion-pip'

@description('The name of the Key Vault')
param kvName string = '${environment}-simpoc-kvault'

@description('Object ID of the user who needs admin access')
param objectId string

@description('Log Analytics Workspace name')
param lawName string = '${environment}-law'

param loadBalancerName string = '${environment}-lb'

param natGatewayName string = '${environment}-nat-gateway'

param natGatewayPipName string = '${environment}-nat-gateway-pip'

@description('Email addresses for warning alerts')
param warningAlertEmails array

@secure()
@description('SSH public key')
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
 
 param dcrName string

 param vmssName string = '${environment}-vmss'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

module virtualNetwork 'modules/virtualnetwork.bicep' = {
  name: '${environment}-vnet'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    vnetName: vnetName
    appSubnetName: appSubnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    appNsgName: appNsgName
    bastionNsgName: bastionNsgName
    natGatewayId: natGateway.outputs.natGatewayId
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
  }
}

module bastion 'modules/bastion.bicep' = {
  name: '${environment}-bastion'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    bastionName: bastionName
    bastionPipName: bastionPipName
    bastionSubnetId: virtualNetwork.outputs.bastionSubnetId
  }
}

module natGateway 'modules/nat-gateway.bicep' = {
  name: '${environment}-nat-gateway'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    natGatewayName: natGatewayName
    natGatewayPipName: natGatewayPipName
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
  }
}

module userAssignedIdentity 'modules/managed-identity.bicep' = {
  scope: resourceGroup
  name: 'kv-identity'
  params: {
    identityName: '${environment}-kv-identity'
    location: location
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: kvName
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    kvName: kvName
    objectId: objectId
    userAssignedIdentityPrincipalId: userAssignedIdentity.outputs.principalId
    privateEndpointSubnetId: virtualNetwork.outputs.privateEndpointSubnetId
    vnetName: vnetName
    sshPublicKey: sshPublicKey
    ca_cert: ca_cert
    origin_cert: origin_cert
    origin_key: origin_key
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
    appInsightsConnectionString: applicationinsights.outputs.appInsightsConnectionString
  }
}

module logAnalyticsWorkspace 'modules/loganalyticsworkspace.bicep' = {
  name: '${environment}-law'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    lawName: lawName
  }
}

module actionGroups 'modules/actiongroups.bicep' = {
  name: '${environment}-actiongroups'
  scope: resourceGroup
  params: {
    environment: environment
    tags: tags
    warningAlertEmails: warningAlertEmails
  }
}

module loadBalancer 'modules/loadbalancer.bicep' = {
  name: '${environment}-loadbalancer'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    loadBalancerName: loadBalancerName
    publicIpName: '${environment}-lb-pip'
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
  }
}

module vmScaleSet 'modules/vmscalesets.bicep' = {
  name: vmssName
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    vmssName: vmssName
    adminUsername: 'masadm'
    vmSku: 'Standard_D2s_v3'
    minCapacity: 1
    maxCapacity: 2
    cpuThreshold: 50
    appSubnetId: virtualNetwork.outputs.appSubnetId
    sshPublicKey: sshPublicKey
    backendPoolId: loadBalancer.outputs.backendPoolId
    managedIdentityResourceId: userAssignedIdentity.outputs.identityId
    environment: environment
    dcrName: dcrName
    managedIdentityPrincipalId: userAssignedIdentity.outputs.principalId
    kvName: kvName
  }
  dependsOn: [
    bastion
    keyVault
    actionGroups
  ]
}

module dcrModule 'modules/dataCollectionRule.bicep' = {
  name: 'monitoring-dcr'
    scope: resourceGroup
  params: {
    location: location
    tags: tags
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
    environment: environment
    dcrName: dcrName
    vmssName: vmssName
  }

}


module applicationinsights 'modules/appinsights.bicep' = {
  name: '${environment}-appinsights'
  scope: resourceGroup
  params: {
    location: location
    environment: environment
    tags: tags
    lawWorkspaceId: logAnalyticsWorkspace.outputs.lawWorkspaceId
    appInsightsName: '${environment}-appinsights'
  }
  dependsOn: [
    dcrModule
  ]
}

module availabilityTest 'modules/availability-test.bicep' = {
  name: '${environment}-availability-test'
  scope: resourceGroup
  params: {
    appName: '${environment}-static-website'
    location: location
    tags: tags
    appInsightsId: applicationinsights.outputs.appInsightsId
    publicIpAddress: loadBalancer.outputs.loadBalancerPublicIp
    warningActionGroupId: actionGroups.outputs.warningActionGroupId
  }
  dependsOn: [
    keyVault
    userAssignedIdentity
    virtualNetwork
    bastion
    natGateway
    vmScaleSet
  ]
}
