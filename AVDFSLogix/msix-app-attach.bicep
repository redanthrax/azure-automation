@description('Azure region for deployment')
param location string

@description('Storage account name for MSIX packages')
param msixStorageAccountName string

@description('File share name for MSIX packages')
param msixFileShareName string = 'msixapps'

@description('Storage account SKU for MSIX packages')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
param msixStorageAccountSku string = 'Premium_LRS'

@description('File share quota in GB for MSIX packages')
@minValue(100)
@maxValue(102400)
param msixFileShareQuota int = 1024

@description('Host pool name for MSIX app attach')
param hostPoolName string

@description('MSIX packages to configure')
param msixPackages array = [
  {
    packageName: 'Microsoft.Office.Desktop'
    displayName: 'Microsoft 365 Apps'
    imagePath: '\\\\${msixStorageAccountName}.file.${environment().suffixes.storage}\\${msixFileShareName}\\Office365.vhd'
    packageFamilyName: 'Microsoft.Office.Desktop_8wekyb3d8bbwe'
    isActive: true
    isRegularRegistration: false
    packageApplications: [
      {
        appId: 'Microsoft.Office.Desktop.Word'
        description: 'Microsoft Word'
        appUserModelId: 'Microsoft.Office.Desktop.Word'
        friendlyName: 'Word'
        iconImageName: 'Word.ico'
        rawIcon: ''
        rawPng: ''
      }
      {
        appId: 'Microsoft.Office.Desktop.Excel'
        description: 'Microsoft Excel'
        appUserModelId: 'Microsoft.Office.Desktop.Excel'
        friendlyName: 'Excel'
        iconImageName: 'Excel.ico'
        rawIcon: ''
        rawPng: ''
      }
      {
        appId: 'Microsoft.Office.Desktop.PowerPoint'
        description: 'Microsoft PowerPoint'
        appUserModelId: 'Microsoft.Office.Desktop.PowerPoint'
        friendlyName: 'PowerPoint'
        iconImageName: 'PowerPoint.ico'
        rawIcon: ''
        rawPng: ''
      }
    ]
  }
]

// Storage account for MSIX packages
resource msixStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: msixStorageAccountName
  location: location
  kind: 'FileStorage'
  sku: {
    name: msixStorageAccountSku
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

// File service for MSIX storage
resource msixFileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: msixStorageAccount
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

// File share for MSIX packages
resource msixFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: msixFileService
  name: msixFileShareName
  properties: {
    shareQuota: msixFileShareQuota
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}

// Get existing host pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' existing = {
  name: hostPoolName
}

// MSIX packages configuration
resource msixPackageResources 'Microsoft.DesktopVirtualization/hostPools/msixPackages@2023-09-05' = [for pkg in msixPackages: {
  parent: hostPool
  name: pkg.packageName
  properties: {
    imagePath: pkg.imagePath
    packageName: pkg.packageName
    packageFamilyName: pkg.packageFamilyName
    displayName: pkg.displayName
    packageRelativePath: pkg.packageName
    isActive: pkg.isActive
    isRegularRegistration: pkg.isRegularRegistration
    packageApplications: pkg.packageApplications
  }
}]

// Outputs
output msixStorageAccountId string = msixStorageAccount.id
output msixFileShareUrl string = 'https://${msixStorageAccount.name}.file.${environment().suffixes.storage}/${msixFileShareName}'
output msixPackageNames array = [for pkg in msixPackages: pkg.packageName]
