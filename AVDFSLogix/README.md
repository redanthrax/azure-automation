---
description: This template allows you to create Azure Virtual Desktop resources such as host pool, application group, workspace, FSLogix storage account, file share, recovery service vault for file share backup and session hosts with Entra ID join.
products:
- azure
- azure-resource-manager
urlFragment: azure-virtual-desktop-with-fslogix
languages:
- bicep
- json
---
# Azure Virtual Desktop with FSLogix

## Overview

This template deploys a complete Azure Virtual Desktop environment with FSLogix profile management, including:

- **AVD Host Pool** - Pooled desktop environment
- **Application Group** - Desktop application group  
- **Workspace** - AVD workspace for user access
- **Premium Storage Account** - Optimized for FSLogix profiles
- **File Share** - Azure Files share for profile containers
- **Recovery Services Vault** - Automated backup for file share
- **Session Host VMs** - Windows 11 multi-session with Entra ID join
- **Extensions** - Automatic domain join and AVD agent installation

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AVD Workspace │────│ Application Group│────│   Host Pool     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │ Session Host VMs│
                                               │ (Entra ID Join) │
                                               └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Recovery Vault  │────│   File Share     │────│ Storage Account │
│   (Backup)      │    │   (FSLogix)      │    │   (Premium)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Scalability

### 📊 **Current Capacity**
- **Session Hosts**: Up to 10 VMs (configurable to 200+)
- **Concurrent Users**: ~100 users (10 sessions per VM)
- **Storage**: Single Premium storage account (~100,000 IOPS)

### 🚀 **Scaling Options**

| User Count | Recommended Setup | Monthly Cost Est. |
|------------|-------------------|-------------------|
| 50-100     | 5-10 VMs, 1 Storage Account | $2,000-4,000 |
| 100-500    | 10-50 VMs, 2-3 Storage Accounts | $4,000-20,000 |
| 500-1000   | 50-100 VMs, 3-5 Storage Accounts | $20,000-40,000 |
| 1000+      | VM Scale Sets + Azure NetApp Files | $40,000+ |

### 📈 **Scale-Out Strategies**
1. **Session Hosts**: Increase `numberOfSessionHosts` parameter
2. **Storage**: Deploy multiple storage accounts for load distribution
3. **VM Size**: Scale up to Standard_D8s_v3 for 40+ sessions per VM
4. **Auto-scaling**: Implement VM Scale Sets (see `SCALABILITY.md`)

For detailed scaling guidance, see **[SCALABILITY.md](SCALABILITY.md)**

## Application Deployment

### 🎯 **Modern Application Delivery (Recommended)**
This solution supports multiple application deployment methods:

| Method | Use Case | Benefits |
|--------|----------|----------|
| **MSIX App Attach** | Modern apps, Office 365 | Fast login, easy updates |
| **Custom Image** | Legacy apps, system tools | Traditional, compatible |
| **Intune Deployment** | Managed updates | Centralized, automated |
| **PowerShell DSC** | Configuration management | Declarative, scalable |

### 📦 **Quick Start - MSIX App Attach**
```powershell
# Deploy MSIX infrastructure
az deployment group create \
  --resource-group "rg-avd-fslogix-prod" \
  --template-file "msix-app-attach.bicep" \
  --parameters hostPoolName="hp-avd-fslogix-prod"

# Create MSIX package
.\Create-MSIXPackage.ps1 -AppPath "C:\Apps\MyApp" -OutputPath "C:\MSIX" -PackageName "MyApp"
```

### 🛠️ **Traditional Application Installation**
```powershell
# Install applications on session hosts
.\Install-Applications.ps1 -ConfigPath "app-config.json"
```

For comprehensive application deployment strategies, see **[APPLICATION-DEPLOYMENT.md](APPLICATION-DEPLOYMENT.md)**

## Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **Existing Virtual Network** and subnet for session hosts
3. **Azure PowerShell** or **Azure CLI** installed
4. **Bicep CLI** installed (optional, if using Bicep directly)

## Quick Start

### 1. Update Parameters

Edit `main.parameters.json` with your environment-specific values:

```json
{
  "resourceGroupName": { "value": "rg-avd-fslogix-prod" },
  "location": { "value": "eastus2" },
  "hostPoolName": { "value": "hp-avd-fslogix-prod" },
  "storageAccountName": { "value": "stavdfslogixprod001" },
  "existingVnetResourceGroupName": { "value": "rg-network-prod" },
  "existingVnetName": { "value": "vnet-prod" },
  "existingSubnetName": { "value": "subnet-avd" },
  "adminPassword": { "value": "YourSecurePassword123!" }
}
```

### 2. Deploy Using PowerShell

```powershell
# Run the deployment script
.\deploy.ps1 -SubscriptionId "your-subscription-id"
```

### 3. Deploy Using Azure CLI

```bash
# Login to Azure
az login

# Deploy the template
az deployment sub create \
  --name "avd-fslogix-deployment" \
  --location "eastus2" \
  --template-file "main.bicep" \
  --parameters "@main.parameters.json"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resourceGroupName` | string | - | Name of the resource group for AVD resources |
| `location` | string | eastus2 | Azure region for deployment |
| `hostPoolName` | string | - | Name of the AVD host pool |
| `hostPoolFriendlyName` | string | - | Friendly name visible in AVD client |
| `storageAccountName` | string | - | Storage account name for FSLogix (must be unique) |
| `fileShareName` | string | fslogix | Name of the file share for profiles |
| `recoveryVaultName` | string | - | Recovery services vault name for backup |
| `vmNamePrefix` | string | avd | VM name prefix for session hosts |
| `vmSize` | string | Standard_D2s_v3 | Size of session host VMs |
| `numberOfSessionHosts` | int | 1 | Number of session hosts to deploy |
| `adminUsername` | string | - | Administrator username for VMs |
| `adminPassword` | securestring | - | Administrator password for VMs |
| `existingVnetResourceGroupName` | string | - | Resource group of existing VNet |
| `existingVnetName` | string | - | Name of existing virtual network |
| `existingSubnetName` | string | - | Name of existing subnet for VMs |

## Features

### 🔐 Security
- **Entra ID Join** - Modern authentication without domain controllers
- **Premium Storage** - Enhanced performance and security
- **TLS 1.2** - Secure communication protocols
- **Managed Identity** - Secure authentication for Azure resources

### 📁 FSLogix Configuration
- **Premium File Storage** - Optimized for FSLogix workloads
- **Kerberos Authentication** - Secure file share access
- **Profile Containers** - User profile management
- **Automatic Configuration** - Ready-to-use FSLogix setup

### 💾 Backup & Recovery
- **Automated Backup** - Daily backup of FSLogix profiles
- **Point-in-time Recovery** - Restore user profiles when needed
- **30-day Retention** - Configurable retention policy

### 🖥️ Session Hosts
- **Windows 11 Multi-session** - Latest AVD optimized image
- **Automatic Registration** - Self-registering to host pool
- **Extensions** - Pre-configured with required components
- **Trusted Launch** - Enhanced security features

## Post-Deployment Configuration

### 1. Configure User Access

```powershell
# Add users to the application group
$appGroupName = "ag-avd-fslogix-prod"
$resourceGroupName = "rg-avd-fslogix-prod"
$userPrincipalName = "user@contoso.com"

New-AzRoleAssignment `
  -SignInName $userPrincipalName `
  -RoleDefinitionName "Desktop Virtualization User" `
  -ResourceName $appGroupName `
  -ResourceGroupName $resourceGroupName `
  -ResourceType "Microsoft.DesktopVirtualization/applicationGroups"
```

### 2. Configure FSLogix RBAC

```powershell
# Grant Storage File Data SMB Share Contributor to users
$storageAccountName = "stavdfslogixprod001"
$resourceGroupName = "rg-avd-fslogix-prod"
$userPrincipalName = "user@contoso.com"

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

New-AzRoleAssignment `
  -SignInName $userPrincipalName `
  -RoleDefinitionName "Storage File Data SMB Share Contributor" `
  -Scope $storageAccount.Id
```

### 3. Verify Backup Configuration

Check that backup is properly configured in the Azure portal:
1. Navigate to Recovery Services Vault
2. Verify backup policy is applied to the file share
3. Check backup schedule and retention settings

## Monitoring & Troubleshooting

### Key Metrics to Monitor
- Session host performance and availability
- Storage account metrics and performance
- Backup job success/failure
- User connection success rates

### Common Issues
1. **FSLogix Profile Issues** - Check storage account permissions and network connectivity
2. **Session Host Registration** - Verify host pool registration token and extensions
3. **User Access Issues** - Confirm RBAC assignments and application group membership
4. **Backup Failures** - Check vault configuration and storage account access

## Cleanup

To remove all resources:

```powershell
# Delete the resource group (removes all resources)
Remove-AzResourceGroup -Name "rg-avd-fslogix-prod" -Force
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Azure AVD documentation
3. Open an issue in this repository