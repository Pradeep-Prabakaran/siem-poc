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

@description('Bastion name')
param bastionName string

@description('Bastion Public IP name')
param bastionPipName string

@description('Bastion subnet ID')
param bastionSubnetId string


resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: bastionPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  zones: ['1', '2', '3']
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    enableShareableLink: false
    enableKerberos: false
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: true
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

@description('Bastion Name')
output bastionName string = bastion.name

@description('Bastion Resource ID')
output bastionId string = bastion.id
