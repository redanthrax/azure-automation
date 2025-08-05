@description('Azure region for deployment')
param location string

@description('Name of the AVD host pool')
param hostPoolName string

@description('Friendly name of the host pool visible in AVD client')
param hostPoolFriendlyName string

@description('Name of the application group')
param appGroupName string

@description('Friendly name of the application group')
param appGroupFriendlyName string

@description('Name of the AVD workspace')
param workspaceName string

@description('Host pool type')
@allowed([
  'Pooled'
  'Personal'
])
param hostPoolType string = 'Pooled'

@description('Load balancer type for pooled host pools')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string = 'BreadthFirst'

@description('Maximum session limit for pooled host pools')
@minValue(1)
@maxValue(999999)
param maxSessionLimit int = 20  // Increased from 10 to 20 for better user density

@description('Custom RDP properties')
param customRdpProperty string = 'targetisaadjoined:i:1;drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1'

// AVD Host Pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  properties: {
    hostPoolType: hostPoolType
    maxSessionLimit: maxSessionLimit
    loadBalancerType: loadBalancerType
    validationEnvironment: false
    preferredAppGroupType: 'Desktop'
    customRdpProperty: customRdpProperty
    friendlyName: hostPoolFriendlyName
    startVMOnConnect: true
    publicNetworkAccess: 'Enabled'
  }
}

// Application Group
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
    friendlyName: appGroupFriendlyName
  }
}

// Workspace
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
    friendlyName: workspaceName
    publicNetworkAccess: 'Enabled'
  }
}

// Outputs
output hostPoolId string = hostPool.id
output hostPoolName string = hostPool.name
output appGroupId string = appGroup.id
output appGroupName string = appGroup.name
output workspaceId string = workspace.id
output workspaceName string = workspace.name
