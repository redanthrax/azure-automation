param location string

param hostPoolName string

@description('Friendly Name of the Host Pool, this is visible via the AVD client')
param hostPoolFriendlyName string

param hostPoolType string = 'Pooled'

@allowed([
  'BreadthFirst'
  'DepthFirst'
  'Persistent'
])
param loadBalancerType string = 'BreadthFirst'

@description('Custom RDP properties to be applied to the AVD Host Pool.')
param customRdpProperty string = 'targetisaadjoined:i:1;drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1'

param maxSessionLimit int = 12

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  properties: {
    friendlyName: hostPoolFriendlyName
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    customRdpProperty: customRdpProperty
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxSessionLimit
    validationEnvironment: false
  }
}

var appGroupName = '${hostPoolName}-DAG'

param appGroupFriendlyName string

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  properties: {
    friendlyName: appGroupFriendlyName
    applicationGroupType: 'Desktop'
    description: 'Desktop Application Group'
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization/hostPools', hostPoolName)
  }
  dependsOn: [
    hostPool
  ]
}

@description('Name of the AVD Workspace to used for this deployment')
param workspaceName string

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: array(resourceId('Microsoft.DesktopVirtualization/applicationgroups/', appGroupName))
  }
  dependsOn: [
    applicationGroup
  ]
}
