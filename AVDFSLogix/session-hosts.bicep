@description('Azure region for deployment')
param location string

@description('VM name prefix for session hosts')
param vmNamePrefix string

@description('Size of the session host VMs')
param vmSize string

@description('Number of VMs to deploy')
@minValue(1)
@maxValue(100)  // Increased from 10 to 100 for better scaling
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

// Note: AVD Host Registration will be done via separate script after deployment
// This avoids complex token expression issues during deployment

// Get subnet reference
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: '${existingVnetName}/${existingSubnetName}'
  scope: resourceGroup(existingVnetResourceGroupName)
}

// Create Network Interfaces
resource networkInterfaces 'Microsoft.Network/networkInterfaces@2023-05-01' = [for i in range(0, numberOfVMs): {
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

// Create Virtual Machines
resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, numberOfVMs): {
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

// Azure AD Join Extension
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, numberOfVMs): {
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

// Note: AVD Host Registration will be done via separate script after deployment
// This ensures VMs are properly joined to Azure AD first

// FSLogix Configuration Extension using script-based approach
resource fslogixExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, numberOfVMs): {
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
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "# Download and install FSLogix; $fslogixUrl = \'https://aka.ms/fslogix_download\'; $tempPath = \'C:\\temp\'; New-Item -ItemType Directory -Path $tempPath -Force; $zipPath = Join-Path $tempPath \'FSLogix.zip\'; try { Invoke-WebRequest -Uri $fslogixUrl -OutFile $zipPath; Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force; $installerPath = Get-ChildItem -Path $tempPath -Recurse -Filter \'FSLogixAppsSetup.exe\' | Select-Object -First 1; if ($installerPath) { Start-Process -FilePath $installerPath.FullName -ArgumentList \'/install /quiet /norestart\' -Wait } } catch { Write-Host \'FSLogix download failed, continuing with registry configuration\' }; # Configure FSLogix registry settings; New-Item -Path \'HKLM:\\SOFTWARE\\FSLogix\' -Force; New-Item -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Force; Set-ItemProperty -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Name \'Enabled\' -Value 1 -Type DWord; Set-ItemProperty -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Name \'VHDLocations\' -Value \'\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${fileShareName}\' -Type MultiString"'
    }
  }
  dependsOn: [
    aadJoinExtension[i]
  ]
}]

// Outputs
output vmNames array = [for i in range(0, numberOfVMs): virtualMachines[i].name]
output vmIds array = [for i in range(0, numberOfVMs): virtualMachines[i].id]
