@description('Azure region for deployment')
param location string

@description('VM name prefix for session hosts')
param vmNamePrefix string

@description('Size of the session host VMs')
param vmSize string

@description('Number of VMs to deploy')
@minValue(1)
@maxValue(200)  // Increased from 10 to 200
param numberOfVMs int

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

@description('Host pool name for registration')
param hostPoolName string

@description('Storage account name for FSLogix')
param storageAccountName string

@description('File share name for FSLogix')
param fileShareName string

@description('VM image publisher')
param imagePublisher string = 'microsoftwindowsdesktop'

@description('VM image offer')
param imageOffer string = 'windows-11'

@description('VM image SKU')
param imageSku string = 'win11-23h2-avd'

@description('VM image version')
param imageVersion string = 'latest'

@description('Number of storage accounts for load distribution')
@minValue(1)
@maxValue(10)
param numberOfStorageAccounts int = 1

@description('Enable VM Scale Sets for auto-scaling')
param enableVmss bool = false

@description('Minimum number of VMs in scale set')
@minValue(0)
param vmssMinInstances int = 2

@description('Maximum number of VMs in scale set')
@minValue(1)
@maxValue(1000)
param vmssMaxInstances int = 100

@description('Availability zones for session hosts')
param availabilityZones array = ['1', '2', '3']

// Get subnet reference
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: '${existingVnetName}/${existingSubnetName}'
  scope: resourceGroup(existingVnetResourceGroupName)
}

// Get host pool reference for token
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' existing = {
  name: hostPoolName
}

// Create multiple storage accounts for load distribution
resource additionalStorageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' = [for i in range(1, numberOfStorageAccounts - 1): if (numberOfStorageAccounts > 1) {
  name: '${take(storageAccountName, 18)}${padLeft(i + 1, 3, '0')}'
  location: location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
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
}]

// File services for additional storage accounts
resource additionalFileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = [for i in range(1, numberOfStorageAccounts - 1): if (numberOfStorageAccounts > 1) {
  parent: additionalStorageAccounts[i - 1]
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
}]

// File shares for additional storage accounts
resource additionalFileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = [for i in range(1, numberOfStorageAccounts - 1): if (numberOfStorageAccounts > 1) {
  parent: additionalFileServices[i - 1]
  name: fileShareName
  properties: {
    shareQuota: 5120  // 5TB for larger user base
    enabledProtocols: 'SMB'
    accessTier: 'Premium'
  }
}]

// VM Scale Set for auto-scaling (when enabled)
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = if (enableVmss) {
  name: '${vmNamePrefix}-vmss'
  location: location
  zones: availabilityZones
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: vmssMinInstances
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: vmNamePrefix
        adminUsername: adminUsername
        adminPassword: adminPassword
        windowsConfiguration: {
          enableAutomaticUpdates: true
          provisionVMAgent: true
          patchSettings: {
            patchMode: 'AutomaticByOS'
            assessmentMode: 'ImageDefault'
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: imagePublisher
          offer: imageOffer
          sku: imageSku
          version: imageVersion
        }
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmNamePrefix}-nic-config'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: subnet.id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      securityProfile: {
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
        securityType: 'TrustedLaunch'
      }
      licenseType: 'Windows_Client'
      extensionProfile: {
        extensions: [
          {
            name: 'AADLoginForWindows'
            properties: {
              publisher: 'Microsoft.Azure.ActiveDirectory'
              type: 'AADLoginForWindows'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              settings: {
                mdmId: '0000000a-0000-0000-c000-000000000000'
              }
            }
          }
          {
            name: 'Microsoft-PowerShell-DSC'
            properties: {
              publisher: 'Microsoft.Powershell'
              type: 'DSC'
              typeHandlerVersion: '2.77'
              autoUpgradeMinorVersion: true
              settings: {
                modulesUrl: 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_09-08-2022.zip'
                configurationFunction: 'Configuration.ps1\\AddSessionHost'
                properties: {
                  hostPoolName: hostPoolName
                  registrationInfoToken: hostPool.listRegistrationTokens().value[0].token
                  aadJoin: true
                  UseAgentDownloadEndpoint: true
                  aadJoinPreview: false
                  mdmId: '0000000a-0000-0000-c000-000000000000'
                }
              }
            }
          }
          {
            name: 'FSLogixConfiguration'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.10'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: []
                commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "New-Item -Path HKLM:\\SOFTWARE\\FSLogix -Force; New-Item -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Force; Set-ItemProperty -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Name Enabled -Value 1 -Type DWord; Set-ItemProperty -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Name VHDLocations -Value \\"\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${fileShareName}\\" -Type MultiString"'
              }
            }
          }
        ]
      }
    }
  }
}

// Auto-scaling rules for VM Scale Set
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableVmss) {
  name: '${vmNamePrefix}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: vmss.id
    profiles: [
      {
        name: 'default'
        capacity: {
          minimum: string(vmssMinInstances)
          maximum: string(vmssMaxInstances)
          default: string(vmssMinInstances)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

// Traditional VMs (when not using VMSS)
resource networkInterfaces 'Microsoft.Network/networkInterfaces@2023-05-01' = [for i in range(0, numberOfVMs): if (!enableVmss) {
  name: '${vmNamePrefix}-${i}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
}]

resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, numberOfVMs): if (!enableVmss) {
  name: '${vmNamePrefix}-${i}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmNamePrefix}-${i}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces[i].id
        }
      ]
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
    licenseType: 'Windows_Client'
  }
}]

// Extensions for traditional VMs
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, numberOfVMs): if (!enableVmss) {
  parent: virtualMachines[i]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    }
  }
}]

resource avdHostExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, numberOfVMs): if (!enableVmss) {
  parent: virtualMachines[i]
  name: 'Microsoft.PowerShell.DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_09-08-2022.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        registrationInfoToken: hostPool.listRegistrationTokens().value[0].token
        aadJoin: true
        UseAgentDownloadEndpoint: true
        aadJoinPreview: false
        mdmId: '0000000a-0000-0000-c000-000000000000'
      }
    }
  }
  dependsOn: [
    aadJoinExtension[i]
  ]
}]

// Multi-storage FSLogix configuration for traditional VMs
resource fslogixExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, numberOfVMs): if (!enableVmss) {
  parent: virtualMachines[i]
  name: 'FSLogixConfiguration'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "New-Item -Path HKLM:\\SOFTWARE\\FSLogix -Force; New-Item -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Force; Set-ItemProperty -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Name Enabled -Value 1 -Type DWord; Set-ItemProperty -Path HKLM:\\SOFTWARE\\FSLogix\\Profiles -Name VHDLocations -Value \\"\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${fileShareName}\\" -Type MultiString"'
    }
  }
  dependsOn: [
    avdHostExtension[i]
  ]
}]

// Outputs - VM Scale Set outputs
output vmssId string = enableVmss ? vmss.id : ''
output vmssName string = enableVmss ? vmss.name : ''

// Outputs - Traditional VM outputs  
output vmNames array = [for i in range(0, enableVmss ? 0 : numberOfVMs): enableVmss ? '' : virtualMachines[i].name]
output vmIds array = [for i in range(0, enableVmss ? 0 : numberOfVMs): enableVmss ? '' : virtualMachines[i].id]

// Storage outputs
output storageAccountName string = storageAccountName
output additionalStorageAccounts array = numberOfStorageAccounts > 1 ? map(range(1, numberOfStorageAccounts - 1), i => '${take(storageAccountName, 20)}${padLeft(i + 1, 2, '0')}') : []
