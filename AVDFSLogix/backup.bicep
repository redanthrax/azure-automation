@description('Azure region for deployment')
param location string

@description('Name of the recovery services vault')
param recoveryVaultName string

@description('Name of the storage account to backup')
param storageAccountName string

@description('Resource group name of the storage account')
param storageAccountResourceGroupName string

@description('Name of the file share to backup')
param fileShareName string

@description('Backup policy name')
param backupPolicyName string = 'DefaultFileSharePolicy'

@description('Backup retention days')
@minValue(1)
@maxValue(365)
param retentionDays int = 30

// Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: recoveryVaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    securitySettings: {
      immutabilitySettings: {
        state: 'Disabled'
      }
    }
  }
}

// Backup policy for Azure Files
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: recoveryVault
  name: backupPolicyName
  properties: {
    backupManagementType: 'AzureStorage'
    workLoadType: 'AzureFileShare'
    retentionPolicy: {
      retentionPolicyType: 'SimpleRetentionPolicy'
      retentionDuration: {
        count: retentionDays
        durationType: 'Days'
      }
    }
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2023-01-01T02:00:00Z'
      ]
      scheduleWeeklyFrequency: 0
    }
    timeZone: 'UTC'
  }
}

// Protection container for the storage account
resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-06-01' = {
  name: '${recoveryVault.name}/Azure/storagecontainer;Storage;${storageAccountResourceGroupName};${storageAccountName}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', storageAccountName)
    acquireStorageAccountLock: 'Acquire'
  }
}

// Protected item for the file share
resource protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-06-01' = {
  parent: protectionContainer
  name: 'AzureFileShare;${fileShareName}'
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    policyId: backupPolicy.id
    sourceResourceId: resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts', storageAccountName)
  }
}

// Outputs
output recoveryVaultId string = recoveryVault.id
output recoveryVaultName string = recoveryVault.name
output backupPolicyId string = backupPolicy.id
