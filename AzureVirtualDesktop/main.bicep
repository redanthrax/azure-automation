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

param AzTenantID string

param administratorAccountUsername string

@secure()
param administratorAccountPassword string

param artifactsLocation string

param vmPrefix string = 'AVD'

@allowed([
  'Standard_D2s_v3'
])
param vmSize string

param existingVNETResourceGroup string

param existingVNETName string

param existingSubnetName string

param appID string

@secure()
param appSecret string

param desktopName string

module vms './vms.bicep' = {
  name: 'vms'
  scope: resourceGroup(avdResourceGroup)
  params: {
    AzTenantID: AzTenantID
    location: targetLocation
    administratorAccountUserName: administratorAccountUsername
    administratorAccountPassword: administratorAccountPassword
    artifactsLocation: artifactsLocation
    vmPrefix: vmPrefix
    vmSize: vmSize
    existingVNETResourceGroup: existingVNETResourceGroup
    existingVNETName: existingVNETName
    existingSubnetName: existingSubnetName
    hostPoolName: hostPoolName
    appGroupName: reference(extensionResourceId('/subscriptions/${subscription().subscriptionId}/resourceGroups/${avdResourceGroup}', 'Microsoft.Resources/deployments', 'backPlane'), '2023-09-05').outputs.appGroupName.value
    appID: appID
    appSecret: appSecret
    desktopName: desktopName
    resourceGroupName: avdResourceGroup
  }
  dependsOn: [
    backPlane
  ]
}
