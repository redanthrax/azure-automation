targetScope = 'subscription'

@description('Name of the resource group for AVD resources')
param resourceGroupName string

@description('Azure region for deployment')
@allowed([
  'eastus'
  'eastus2'
  'westus2'
  'westus3'
  'centralus'
  'northeurope'
  'westeurope'
])
param location string = 'eastus2'

@description('Name of the AVD host pool')
param hostPoolName string

@description('Friendly name of the host pool visible in AVD client')
param hostPoolFriendlyName string

@description('Name of the application group')
param appGroupName string = '${hostPoolName}-dag'

@description('Friendly name of the application group')
param appGroupFriendlyName string

@description('Name of the AVD workspace')
param workspaceName string

@description('Name of the storage account for FSLogix profiles')
param storageAccountName string

@description('Name of the file share for FSLogix profiles')
param fileShareName string = 'fslogix'

@description('Name of the recovery services vault for backup')
param recoveryVaultName string

@description('VM name prefix for session hosts')
param vmNamePrefix string = 'avd'

@description('Size of the session host VMs')
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
])
param vmSize string = 'Standard_D2s_v3'

@description('Number of session hosts to deploy')
@minValue(1)
@maxValue(10)
param numberOfSessionHosts int = 1

@description('Administrator username for VMs')
param adminUsername string

@description('Administrator password for VMs')
@secure()
param adminPassword string

@description('Existing virtual network resource group name')
param existingVnetResourceGroupName string

@description('Existing virtual network name')
param existingVnetName string

@description('Existing subnet name for session hosts')
param existingSubnetName string

@description('Enable MSIX App Attach infrastructure')
param enableMsixAppAttach bool = false

@description('Storage account name for MSIX packages (if enabled)')
param msixStorageAccountName string = '${take(storageAccountName, 20)}msix'

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// Deploy storage account and file share for FSLogix
module storage 'storage.bicep' = {
  name: 'storage-deployment'
  scope: rg
  params: {
    location: location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
}

// Deploy recovery services vault and backup
module backup 'backup.bicep' = {
  name: 'backup-deployment'
  scope: rg
  params: {
    location: location
    recoveryVaultName: recoveryVaultName
    storageAccountName: storageAccountName
    storageAccountResourceGroupName: resourceGroupName
    fileShareName: fileShareName
  }
  dependsOn: [
    storage
  ]
}

// Deploy AVD resources
module avdResources 'avd-resources.bicep' = {
  name: 'avd-resources-deployment'
  scope: rg
  params: {
    location: location
    hostPoolName: hostPoolName
    hostPoolFriendlyName: hostPoolFriendlyName
    appGroupName: appGroupName
    appGroupFriendlyName: appGroupFriendlyName
    workspaceName: workspaceName
  }
}

// Deploy session hosts
module sessionHosts 'session-hosts.bicep' = {
  name: 'session-hosts-deployment'
  scope: rg
  params: {
    location: location
    vmNamePrefix: vmNamePrefix
    vmSize: vmSize
    numberOfVMs: numberOfSessionHosts
    adminUsername: adminUsername
    adminPassword: adminPassword
    existingVnetResourceGroupName: existingVnetResourceGroupName
    existingVnetName: existingVnetName
    existingSubnetName: existingSubnetName
    hostPoolName: hostPoolName
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
  dependsOn: [
    avdResources
    storage
  ]
}

// Deploy MSIX App Attach (optional)
module msixAppAttach 'msix-app-attach.bicep' = if (enableMsixAppAttach) {
  name: 'msix-app-attach-deployment'
  scope: rg
  params: {
    location: location
    msixStorageAccountName: msixStorageAccountName
    hostPoolName: hostPoolName
  }
  dependsOn: [
    avdResources
  ]
}

// Outputs
output hostPoolId string = avdResources.outputs.hostPoolId
output appGroupId string = avdResources.outputs.appGroupId
output workspaceId string = avdResources.outputs.workspaceId
output storageAccountId string = storage.outputs.storageAccountId
output fileShareUrl string = storage.outputs.fileShareUrl
output recoveryVaultId string = backup.outputs.recoveryVaultId
output msixEnabled bool = enableMsixAppAttach
