targetScope = 'subscription'

param avdResourceGroup string

param hostPoolName string

@description('Friendly Name of the Host Pool, this is visible via the AVD client')
param hostPoolFriendlyName string

@allowed([
  'westus'
  'westus2'
  'westus3'
])
param targetLocation string

param appGroupFriendlyName string

@description('Name of the AVD Workspace to used for this deployment')
param workspaceName string

module resourceGroupDeploy 'resourceGroup.bicep' = {
  name: 'backPlane'
  params: {
    avdResourceGroup: avdResourceGroup
    loc: targetLocation
  }
}

module backPlane 'backPlane.bicep' = {
  name: 'backPlane'
  scope: resourceGroup(avdResourceGroup)
  params: {
    location: targetLocation
    hostPoolName: hostPoolName
    hostPoolFriendlyName: hostPoolFriendlyName
    appGroupFriendlyName: appGroupFriendlyName
    workspaceName: workspaceName
  }
  dependsOn: [
    resourceGroupDeploy
  ]
}

module vms './vms.bicep' = {
  name: 'vms'
  scope: resourceGroup(avdResourceGroup)
  params: {

  }
  dependsOn: [
    backPlane
  ]
}
