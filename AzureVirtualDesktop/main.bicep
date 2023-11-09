targetScope = 'resourceGroup'

@minLength(3)
@maxLength(12)
param hostPoolName string

@minLength(3)
@maxLength(12)
param hostPoolFriendlyName string

@minLength(3)
@maxLength(12)
param applicationGroupName string

@minLength(3)
@maxLength(12)
param workspaceName string

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: resourceGroup().location
  tags: {}
  properties: {
    friendlyName: hostPoolFriendlyName
    publicNetworkAccess: 'Enabled'
    hostPoolType: 'Pooled'
    customRdpProperty: 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;'
    maxSessionLimit: 10
    loadBalancerType: 'BreadthFirst'
    validationEnvironment: false
    vmTemplate: '{"domain":"","galleryImageOffer":"windows-11","galleryImagePublisher":"microsoftwindowsdesktop","galleryImageSKU":"win11-22h2-avd","imageType":"Gallery","customImageId":null,"namePrefix":"AVDVM","osDiskType":"StandardSSD_LRS","vmSize":{"id":"Standard_D2s_v3","cores":2,"ram":8},"galleryItemId":"microsoftwindowsdesktop.windows-11win11-22h2-avd","hibernate":false,"diskSizeGB":0,"securityType":"TrustedLaunch","secureBoot":true,"vTPM":true}'
    preferredAppGroupType: 'Desktop'
    startVMOnConnect: false
  }
}

resource hostPoolDesktopApp 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: applicationGroupName
  location: resourceGroup().location
  kind: 'Desktop'
  properties: {
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization', hostPoolName)
    friendlyName: 'Virtual Desktop'
    applicationGroupType: 'Desktop'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: resourceGroup().location
  tags: {}
  properties: {
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      resourceId('Microsoft.DesktopVirtualization/applicationGroups', applicationGroupName)
    ]
  }
}

