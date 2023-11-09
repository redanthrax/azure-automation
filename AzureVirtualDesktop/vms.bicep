param vmPrefix string

var networkAdapterPostfix = '-nic'

param location string

param existingVNETResourceGroup string

param existingVNETName string

param existingSubnetName string

var subnetID = resourceId(existingVNETResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', existingVNETName, existingSubnetName)

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmPrefix}-${networkAdapterPostfix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetID
          }
        }
      }
    ]
  }
}

param vmSize string

param administratorAccountUserName string

@secure()
param administratorAccountPassword string

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: '${vmPrefix}-0'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSize
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: '${vmPrefix}-0'
      adminUsername: administratorAccountUserName
      adminPassword: administratorAccountPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    storageProfile: {
      osDisk: {
        name: '${vmPrefix}-0-OS'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        osType: 'Windows'
      }
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-22h2-avd'
        version: 'latest'
      }
      dataDisks: []
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmPrefix}-${networkAdapterPostfix}')
        }
      ]
    }
  }
  dependsOn: [
    nic
  ]
}

param artifactsLocation string

resource joindomain 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'joindomain'
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
}

param hostPoolName string

param resourceGroupName string

param appGroupName string

param desktopName string

@secure()
param AzTenantID string

param appID string

@secure()
param appSecret string

resource dscextension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'dscextension'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: '${artifactsLocation}Configuration.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        HostPoolName: hostPoolName
        ResourceGroup: resourceGroupName
        ApplicationGroupName: appGroupName
        DesktopName: desktopName
        AzTenantID: AzTenantID
        AppID: appID
        AppSecret: appSecret
        vmPrefix: vmPrefix
      }
    }
  }
}
