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

// Temporarily disabled for troubleshooting
// @description('Name of the recovery services vault for backup')
// param recoveryVaultName string

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

@description('Create new virtual network or use existing one')
param createNewVnet bool = true

@description('Virtual network address prefix (only used when creating new vnet)')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix (only used when creating new vnet)')
param subnetAddressPrefix string = '10.0.1.0/24'

@description('Existing virtual network resource group name (only used when createNewVnet is false)')
param existingVnetResourceGroupName string = resourceGroupName

@description('Existing virtual network name (only used when createNewVnet is false)')
param existingVnetName string = 'vnet-avd'

@description('Existing subnet name for session hosts (only used when createNewVnet is false)')
param existingSubnetName string = 'subnet-avd'

@description('Enable MSIX App Attach infrastructure')
param enableMsixAppAttach bool = false

@description('Storage account name for MSIX packages (if enabled)')
param msixStorageAccountName string = '${take(storageAccountName, 20)}msix'

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// Deploy virtual network and subnet (conditionally)
module network 'network.bicep' = if (createNewVnet) {
  name: 'network-deployment'
  scope: rg
  params: {
    location: location
    vnetName: existingVnetName
    subnetName: existingSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
  }
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

// Deploy recovery services vault and backup (disabled for troubleshooting)
/*
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
*/

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
    existingVnetResourceGroupName: createNewVnet ? resourceGroupName : existingVnetResourceGroupName
    existingVnetName: existingVnetName
    existingSubnetName: existingSubnetName
    // hostPoolName: hostPoolName  // Temporarily disabled
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
  dependsOn: createNewVnet ? [
    avdResources
    storage
    network
  ] : [
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
// output recoveryVaultId string = backup.outputs.recoveryVaultId  // Temporarily disabled
output msixEnabled bool = enableMsixAppAttach
