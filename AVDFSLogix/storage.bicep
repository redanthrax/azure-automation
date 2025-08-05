@description('Azure region for deployment')
param location string

@description('Name of the storage account for FSLogix profiles')
param storageAccountName string

@description('Name of the file share for FSLogix profiles')
param fileShareName string

@description('Storage account SKU')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
param storageAccountSku string = 'Premium_LRS'

@description('File share quota in GB')
@minValue(100)
@maxValue(102400)
param fileShareQuota int = 5120  // Increased from 1024 to 5120 (5TB) for more users

// Storage account for FSLogix profiles
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'FileStorage'
  sku: {
    name: storageAccountSku
  }
  properties: {
    accessTier: 'Premium'
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
    }
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// File service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM'
      }
    }
  }
}

// File share for FSLogix profiles
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    shareQuota: fileShareQuota
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output fileShareUrl string = 'https://${storageAccount.name}.file.${environment().suffixes.storage}/${fileShareName}'
output fileShareName string = fileShare.name
