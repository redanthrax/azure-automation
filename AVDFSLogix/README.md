# Azure Virtual Desktop with FSLogix - Complete Implementation Guide

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FAVDFSLogix%2Fmain.json)

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Deployment Options](#-deployment-options)
- [Network Configuration Options](#-network-configuration-options)
- [Scalability](#-scalability)
- [Application Deployment](#-application-deployment)
- [Management & Operations](#-management--operations)
- [Monitoring & Health Checks](#-monitoring--health-checks)
- [Troubleshooting](#-troubleshooting)
- [Security Considerations](#-security-considerations)
- [Cost Optimization](#-cost-optimization)

## 🚀 Overview

This template deploys a complete Azure Virtual Desktop environment with FSLogix profile management using **Azure CLI commands instead of PowerShell modules**. The solution provides enterprise-ready AVD infrastructure with automatic scaling, comprehensive monitoring, and modern application deployment capabilities.

### Key Features
- ✅ **Entra ID Join** (no Active Directory dependency)
- ✅ **FSLogix Profile Management** with Premium Storage
- ✅ **Automated Backup** for user profiles
- ✅ **Auto-scaling** with VM Scale Sets
- ✅ **MSIX App Attach** support
- ✅ **Multi-storage Account** support for large deployments
- ✅ **Azure CLI** based deployment and management
- ✅ **Comprehensive Monitoring** and health checks

### Components Deployed
| Component | Purpose | SKU/Type |
|-----------|---------|----------|
| Host Pool | AVD session management | Pooled, Load Balanced |
| Application Group | App publishing | Desktop type |
| Workspace | User portal | Standard |
| Storage Account | FSLogix profiles | Premium FileStorage |
| File Share | Profile containers | 5TB quota |
| Recovery Vault | Profile backup | Standard |
| Session Hosts | User sessions | Windows 11 Multi-session |
| VM Scale Set | Auto-scaling | Optional for enterprise |

## 🏗️ Architecture

### Standard Deployment (2-100 VMs)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AVD Workspace │────│ Application Group│────│   Host Pool     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                       Azure CLI Management             ▼
                    ┌─────────────────────────┐ ┌─────────────────┐
                    │ • deploy-with-azcli.ps1 │ │ Session Host VMs│
                    │ • manage-avd-azcli.ps1  │ │ (Entra ID Join) │
                    │ • monitor-avd-azcli.ps1 │ └─────────────────┘
                    └─────────────────────────┘          │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Recovery Vault  │────│   File Share     │────│ Storage Account │
│   (Backup)      │    │   (FSLogix)      │    │   (Premium)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Enterprise Scale Deployment (100-2000+ VMs)
```
                           Load Balancer
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │ VM Scale Set │ │ VM Scale Set │ │ VM Scale Set │
        │   Zone 1     │ │   Zone 2     │ │   Zone 3     │
        └──────────────┘ └──────────────┘ └──────────────┘
                │               │               │
                └───────────────┼───────────────┘
                                ▼
                    Multi-Storage FSLogix
        ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
        │ Storage #1  │ │ Storage #2  │ │ Storage #3  │
        │ Users A-H   │ │ Users I-P   │ │ Users Q-Z   │
## 🔧 Prerequisites

### Required Tools
- **Azure CLI** (v2.50.0 or later)
- **PowerShell 5.1** or **PowerShell 7+**
- **Bicep CLI** (bundled with Azure CLI)
- **Azure Subscription** with Owner or Contributor permissions

### Installation Commands
```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Verify installation
az version

# Login to Azure
az login

# Install Bicep (if not already installed)
az bicep install
```

### Network Prerequisites
- Existing Virtual Network and Subnet
- Network Security Group allowing RDP/AVD traffic
- DNS resolution for domain join (if hybrid)

## 🏃 Quick Start

### 1. Clone Repository
```powershell
git clone https://github.com/redanthrax/azure-automation.git
cd azure-automation\AVDFSLogix
```

### 2. Configure Parameters
Edit `main.parameters.json`:
```json
{
  "resourceGroupName": { "value": "rg-avd-fslogix-prod" },
  "location": { "value": "westus2" },
  "numberOfSessionHosts": { "value": 2 },
  "vmSize": { "value": "Standard_D4s_v3" },
  "adminUsername": { "value": "avdadmin" },
  "adminPassword": { "value": "YourSecurePassword123!" },
  "existingVnetResourceGroupName": { "value": "rg-network-prod" },
  "existingVnetName": { "value": "vnet-prod" },
  "existingSubnetName": { "value": "subnet-avd" }
}
```

### 3. Deploy Infrastructure
```powershell
# Standard deployment (2-100 VMs)
.\deploy-with-azcli.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "rg-avd-fslogix-prod" -Location "westus2"

# Verify deployment
.\monitor-avd-azcli.ps1 -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod"
```

## 📊 Deployment Options

### Option 1: Standard Deployment (Recommended for <100 users)
```json
{
  "numberOfSessionHosts": { "value": 5 },
  "vmSize": { "value": "Standard_D4s_v3" },
  "useScalableSessionHosts": { "value": false }
}
```
**Capacity**: Up to 100 concurrent users (20 sessions per VM)

### Option 2: Enterprise Scale Deployment (100-2000+ users)
```json
{
  "useScalableSessionHosts": { "value": true },
  "enableVmss": { "value": true },
  "numberOfVMs": { "value": 10 },
  "minInstances": { "value": 2 },
  "maxInstances": { "value": 50 },
  "numberOfStorageAccounts": { "value": 3 }
}
```
**Capacity**: 2000+ concurrent users with auto-scaling

### Option 3: MSIX App Attach Enabled
```json
{
  "enableMsixAppAttach": { "value": true },
  "msixImagePath": { "value": "\\\\storage\\msix\\apps" }
}
```
**Features**: Modern application delivery with MSIX packages

## 🌐 Network Configuration Options

The deployment template supports two networking scenarios:

### Option 1: Create New Virtual Network (Default)
When `createNewVnet` is set to `true` (default), the template creates a new virtual network and subnet.

**Parameters:**
- `createNewVnet`: `true`
- `vnetAddressPrefix`: Network address space (default: "10.0.0.0/16")
- `subnetAddressPrefix`: Subnet address space (default: "10.0.1.0/24")
- `existingVnetName`: Name for the new virtual network

**Usage:**
```powershell
.\deploy-with-azcli.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "AVD-TEST" -Location "westus2"
```

### Option 2: Use Existing Virtual Network
When `createNewVnet` is set to `false`, the template uses an existing virtual network.

**Parameters:**
- `createNewVnet`: `false`
- `existingVnetResourceGroupName`: Resource group containing the existing vnet
- `existingVnetName`: Name of the existing virtual network
- `existingSubnetName`: Name of the existing subnet

**Usage:**
```powershell
.\deploy-with-azcli.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "AVD-PROD" -Location "eastus2" -ParametersFile "main.parameters.existing-vnet.json"
```

### Network Security
- **New VNet**: Automatically creates NSG with RDP (3389) and HTTPS (443) rules
- **Existing VNet**: Uses existing network security configuration
- **IP Planning**: New VNet uses 10.0.0.0/16 (65,534 IPs) with 10.0.1.0/24 subnet (254 IPs)

## 🔄 Scalability

### Current Capacity Matrix
| Deployment Type | Session Hosts | Max Users | Storage Accounts | Auto-Scale |
|----------------|---------------|-----------|------------------|------------|
| **Standard** | 2-100 VMs | 2000 users | 1 | ❌ |
| **Enterprise** | 10-1000 VMs | 10,000+ users | 1-10 | ✅ |
| **Mega Scale** | 1000+ VMs | 50,000+ users | 10+ | ✅ |

### Auto-scaling Configuration
```bicep
// CPU-based scaling
scaleOutCpuThreshold: 70%  // Scale out when CPU > 70%
scaleInCpuThreshold: 25%   // Scale in when CPU < 25%

// Memory-based scaling  
scaleOutMemoryThreshold: 80%  // Scale out when Memory > 80%
scaleInMemoryThreshold: 30%   // Scale in when Memory < 30%

// Time-based scaling
businessHours: 8AM-6PM (Mon-Fri)  // Scale out during business hours
afterHours: 6PM-8AM + Weekends    // Scale in during off hours
```

### Storage Scaling Strategies

#### Single Storage Account (Up to 1000 users)
```
Premium FileStorage: 100,000 IOPS
Recommended: <1000 concurrent users
Cost: $$ (moderate)
```

#### Multiple Storage Accounts (1000-5000 users)
```
3x Premium FileStorage: 300,000 IOPS total
User Distribution: A-H, I-P, Q-Z
Cost: $$$ (higher)
```

#### Azure NetApp Files (5000+ users)
```
Ultra Performance: 4.5M IOPS
Latency: <1ms
Cost: $$$$ (premium)
```

### Scalability Recommendations by User Count

| User Count | Deployment | Storage | VM Size | Estimated Cost/Month |
|------------|------------|---------|---------|---------------------|
| **2-50** | Standard (2-5 VMs) | Single Premium | D4s_v3 | $800-2000 |
| **50-200** | Standard (5-20 VMs) | Single Premium | D4s_v3 | $2000-8000 |
| **200-1000** | Enterprise (VMSS) | Multi Premium | D8s_v3 | $8000-40000 |
| **1000-5000** | Enterprise (VMSS) | Azure NetApp | D16s_v3 | $40000-200000 |
| **5000+** | Mega Scale | Azure NetApp Ultra | D32s_v3 | $200000+ |

## 📱 Application Deployment

### 1. MSIX App Attach (Recommended Modern Approach)

#### What is MSIX App Attach?
- **Dynamic Application Delivery**: Applications packaged as MSIX and mounted at runtime
- **Just-in-Time**: Applications appear instantly without installation
- **Separation**: Apps, OS, and user data remain separate

#### Benefits
- ✅ **Fast Login Times**: No app installation during login
- ✅ **Reduced Image Size**: Base image contains only OS
- ✅ **Easy Updates**: Update packages without touching hosts
- ✅ **Resource Efficient**: Apps share resources across sessions

#### Implementation
```powershell
# Enable MSIX App Attach in deployment
{
  "enableMsixAppAttach": { "value": true },
  "msixImagePath": { "value": "\\\\stavdfslogix001.file.core.windows.net\\msix" }
}

# Create MSIX packages using our script
.\scripts\Create-MSIXPackage.ps1 -SourcePath "C:\Program Files\MyApp" -PackageName "MyApp" -OutputPath "\\storage\msix\"
```

#### Supported Applications
- Microsoft 365 Apps
- Adobe Creative Suite
- Google Chrome
- Custom Line-of-Business Apps

### 2. Custom Image with Pre-installed Apps (Traditional)

#### When to Use
- Legacy applications that don't support MSIX
- Complex application dependencies
- Regulatory compliance requirements

#### Implementation
```powershell
# Build custom image with applications
# 1. Create VM from marketplace image
# 2. Install applications
# 3. Run sysprep
# 4. Create managed image
# 5. Update template to use custom image

# Update main.parameters.json
{
  "imageResourceId": { 
    "value": "/subscriptions/xxx/resourceGroups/rg-images/providers/Microsoft.Compute/images/avd-custom-image" 
  }
}
```

### 3. Application Layering with FSLogix App Masking

#### What is App Masking?
- **Selective Application Delivery**: Show/hide apps based on user/group membership
- **Single Image, Multiple Experiences**: One image serves different user types
- **Rule-Based**: XML rules define app visibility

#### Implementation
```xml
<!-- FSLogix App Masking Rule Example -->
<FrxContainerRules>
  <Rule>
    <Path>C:\Program Files\Adobe</Path>
    <Group>Designers</Group>
    <Action>Allow</Action>
  </Rule>
  <Rule>
    <Path>C:\Program Files\Adobe</Path>
    <Group>*</Group>
    <Action>Hide</Action>
  </Rule>
</FrxContainerRules>
```

### 4. Per-App Entitlement (RemoteApp)

#### When to Use
- Specific application access (not full desktop)
- Different user groups need different apps
- Granular access control required

#### Implementation
```powershell
# Create RemoteApp application group
az desktopvirtualization applicationgroup create \
  --name "ag-remoteapps" \
  --resource-group "rg-avd" \
  --application-group-type "RemoteApp" \
  --host-pool-arm-path "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-avd"

# Add applications to RemoteApp group
az desktopvirtualization application create \
  --name "Word" \
  --resource-group "rg-avd" \
  --application-group-name "ag-remoteapps" \
  --command-line-setting "Allow" \
  --file-path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
```

## 🛠️ Management & Operations

### Common Management Tasks

#### Session Management
```powershell
# List active sessions
.\manage-avd-azcli.ps1 -Operation "ListSessions" -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod"

# Set drain mode (prevent new sessions)
.\manage-avd-azcli.ps1 -Operation "DrainMode" -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod" -SessionHostName "avd-vm-001" -AllowNewSessions $false

# Force logoff user sessions
az desktopvirtualization session delete --session-id "SessionID" --host-pool-name "hp-avd-fslogix-prod" --resource-group "rg-avd-fslogix-prod"
```

#### VM Management
```powershell
# Restart session host
.\manage-avd-azcli.ps1 -Operation "RestartVM" -ResourceGroupName "rg-avd-fslogix-prod" -SessionHostName "avd-vm-001"

# Start/Stop VMs for cost optimization
az vm start --name "avd-vm-001" --resource-group "rg-avd-fslogix-prod"
az vm deallocate --name "avd-vm-001" --resource-group "rg-avd-fslogix-prod"
```

#### User Management
```powershell
# Assign users to application group
.\manage-avd-azcli.ps1 -Operation "AssignUsers" -ResourceGroupName "rg-avd-fslogix-prod" -ApplicationGroupName "ag-avd-fslogix-prod" -UserPrincipalNames @("user1@domain.com", "user2@domain.com")

# Remove user assignment
az role assignment delete --assignee "user@domain.com" --role "Desktop Virtualization User" --scope "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/applicationGroups/ag-avd"
```

#### Host Pool Configuration
```powershell
# Update host pool settings
az desktopvirtualization hostpool update \
  --name "hp-avd-fslogix-prod" \
  --resource-group "rg-avd-fslogix-prod" \
  --max-session-limit 25 \
  --load-balancer-type "BreadthFirst"

# Generate new registration token
az desktopvirtualization hostpool retrieve-registration-token \
  --name "hp-avd-fslogix-prod" \
  --resource-group "rg-avd-fslogix-prod"
```

### Automated Operations

#### Scheduled VM Start/Stop
```powershell
# Create automation account and runbook for cost optimization
# Start VMs at 8 AM on weekdays
# Stop VMs at 6 PM on weekdays
# Keep minimal VMs running on weekends
```

#### Health Check Automation
```powershell
# Schedule health checks every 15 minutes
.\monitor-avd-azcli.ps1 -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod"
```

## 📊 Monitoring & Health Checks

### Built-in Health Monitoring
The `monitor-avd-azcli.ps1` script provides comprehensive health checks:

#### System Health Checks
- ✅ **Host Pool Status**: Configuration and registration token validity
- ✅ **Session Host Health**: Availability, status, and session counts
- ✅ **Active Sessions**: User sessions and connection states
- ✅ **Storage Account Status**: FSLogix storage health and file shares
- ✅ **Virtual Machine Status**: Power states and performance
- ✅ **Application Group**: Configuration and app availability

#### Usage Example
```powershell
# Basic health check
.\monitor-avd-azcli.ps1 -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod"

# Enhanced monitoring with Log Analytics
.\monitor-avd-azcli.ps1 -ResourceGroupName "rg-avd-fslogix-prod" -HostPoolName "hp-avd-fslogix-prod" -LogAnalyticsWorkspace "workspace-id" -Hours 24
```

#### Sample Output
```
=== AVD Environment Health Check ===

1. Host Pool Status
[Healthy] Host Pool - Type: Pooled, Load Balancer: BreadthFirst
   Max Sessions: 20
   Registration Token Valid: True

2. Session Hosts Status
[Healthy] Session Hosts - 5/5 hosts available
  [Healthy] avd-vm-001 - Status: Available, Sessions: 3
  [Healthy] avd-vm-002 - Status: Available, Sessions: 5
  [Warning] avd-vm-003 - Status: Unavailable, Sessions: 0

3. Active Sessions
[Healthy] Active Sessions - 15 active sessions
   User: john@company.com, Host: avd-vm-001, State: Active
   User: jane@company.com, Host: avd-vm-002, State: Active
```

### Log Analytics Integration

#### Enable Diagnostics
```powershell
# Enable diagnostics for host pool
az monitor diagnostic-settings create \
  --name "avd-diagnostics" \
  --resource "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-avd" \
  --workspace "/subscriptions/xxx/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/la-avd" \
  --logs '[{"category":"Connection","enabled":true},{"category":"Management","enabled":true}]'
```

#### Key Queries
```kql
// Connection failures in last 24 hours
WVDConnections
| where TimeGenerated > ago(24h)
| where State == "Failed"
| summarize count() by bin(TimeGenerated, 1h), UserName

// Top users by session duration
WVDConnections  
| where TimeGenerated > ago(7d)
| where State == "Completed"
| extend Duration = datetime_diff('minute', SessionEndTime, SessionStartTime)
| summarize AvgDuration = avg(Duration) by UserName
| top 10 by AvgDuration

// Session host performance
WVDCheckpoints
| where TimeGenerated > ago(1h)
| where Source == "Connection"
| summarize avg(ResponseTime) by SessionHostName
```

### Azure Monitor Alerts

#### Recommended Alerts
```powershell
# High CPU utilization
az monitor metrics alert create \
  --name "AVD High CPU" \
  --resource-group "rg-avd" \
  --scopes "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.Compute/virtualMachines/avd-vm-001" \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m

# Session host unavailable
az monitor metrics alert create \
  --name "AVD Host Unavailable" \
  --resource-group "rg-avd" \
  --condition "max AvailableSessionSlots < 1" \
  --window-size 5m
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Session Host Registration Failures
**Symptoms**: Session hosts not appearing in host pool
**Solutions**:
```powershell
# Check registration token validity
az desktopvirtualization hostpool show --name "hp-avd" --resource-group "rg-avd" --query "registrationInfo"

# Generate new token if expired
az desktopvirtualization hostpool retrieve-registration-token --name "hp-avd" --resource-group "rg-avd"

# Re-run registration on session host
# This is done automatically by the CustomScript extension
```

#### 2. FSLogix Profile Loading Issues
**Symptoms**: Slow login, profile corruption
**Solutions**:
```powershell
# Check storage account connectivity
Test-NetConnection -ComputerName "stavdfslogix001.file.core.windows.net" -Port 445

# Verify file share permissions
$storageContext = New-AzStorageContext -StorageAccountName "stavdfslogix001" -UseConnectedAccount
Get-AzStorageFileContent -ShareName "fslogix" -Path "test.txt" -Context $storageContext

# Review FSLogix event logs on session host
Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" | Where-Object {$_.LevelDisplayName -eq "Error"}
```

#### 3. Application Launch Failures
**Symptoms**: Apps not starting, RemoteApp issues
**Solutions**:
```powershell
# Verify application registration
az desktopvirtualization application list --application-group-name "ag-remoteapps" --resource-group "rg-avd"

# Check application file path exists on session hosts
# Connect to session host and verify path

# Review application event logs
Get-EventLog -LogName Application -Source "Microsoft-Windows-TerminalServices-RemoteConnectionManager"
```

#### 4. Network Connectivity Issues
**Symptoms**: Cannot connect to sessions, slow performance
**Solutions**:
```powershell
# Check NSG rules
az network nsg rule list --nsg-name "nsg-avd" --resource-group "rg-network"

# Verify subnet has proper routes
az network route-table route list --route-table-name "rt-avd" --resource-group "rg-network"

# Test UDP SHORTPATH (if enabled)
Test-NetConnection -ComputerName "avd-vm-001.domain.com" -Port 3390 -InformationLevel Detailed
```

#### 5. Auto-scaling Not Working
**Symptoms**: VMSS not scaling up/down as expected
**Solutions**:
```powershell
# Check auto-scale rules
az monitor autoscale rule list --autoscale-name "avd-autoscale" --resource-group "rg-avd"

# Review auto-scale history
az monitor autoscale history list --autoscale-name "avd-autoscale" --resource-group "rg-avd"

# Verify metrics are being collected
az monitor metrics list --resource "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-avd"
```

### Diagnostic Commands

#### System Information
```powershell
# Get overall environment status
.\monitor-avd-azcli.ps1 -ResourceGroupName "rg-avd" -HostPoolName "hp-avd"

# Check specific session host
az desktopvirtualization sessionhost show --name "avd-vm-001" --host-pool-name "hp-avd" --resource-group "rg-avd"

# List all resources in AVD resource group
az resource list --resource-group "rg-avd" --output table
```

#### Log Collection
```powershell
# Export activity logs for troubleshooting
az monitor activity-log list --resource-group "rg-avd" --start-time "2024-01-01" --output table

# Get VM diagnostics
az vm get-instance-view --name "avd-vm-001" --resource-group "rg-avd" --query "instanceView.statuses"
```

## 🔒 Security Considerations

### Identity and Access Management

#### Entra ID Integration
```powershell
# Configure conditional access for AVD
# 1. Create conditional access policy in Entra ID
# 2. Target "Azure Virtual Desktop" cloud app
# 3. Apply MFA and device compliance requirements

# Assign users to AVD groups
az ad group member add --group "AVD-Users" --member-id "user-object-id"
```

#### Role-Based Access Control (RBAC)
```powershell
# Custom roles for AVD management
az role definition create --role-definition '{
  "Name": "AVD Session Host Operator",
  "Description": "Can manage AVD session hosts",
  "Actions": [
    "Microsoft.DesktopVirtualization/hostpools/sessionhosts/*",
    "Microsoft.Compute/virtualMachines/restart/action",
    "Microsoft.Compute/virtualMachines/start/action"
  ],
  "AssignableScopes": ["/subscriptions/subscription-id"]
}'
```

### Network Security

#### Network Security Groups
```powershell
# AVD-specific NSG rules
az network nsg rule create \
  --resource-group "rg-network" \
  --nsg-name "nsg-avd" \
  --name "Allow-AVD-Inbound" \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "WindowsVirtualDesktop" \
  --destination-port-ranges 443 \
  --priority 100
```

#### Private Endpoints
```powershell
# Enable private endpoints for storage account
az storage account update \
  --name "stavdfslogix001" \
  --resource-group "rg-avd" \
  --default-action Deny

az network private-endpoint create \
  --name "pe-storage-avd" \
  --resource-group "rg-avd" \
  --vnet-name "vnet-avd" \
  --subnet "subnet-private-endpoints" \
  --private-connection-resource-id "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.Storage/storageAccounts/stavdfslogix001" \
  --group-id file \
  --connection-name "storage-connection"
```

### Data Protection

#### FSLogix Profile Encryption
```powershell
# Enable FSLogix profile disk encryption
reg add "HKLM\SOFTWARE\FSLogix\Profiles" /v VHDAccessMode /t REG_DWORD /d 3
reg add "HKLM\SOFTWARE\FSLogix\Profiles" /v VolumeType /t REG_DWORD /d 0
```

#### Storage Account Security
```powershell
# Enable storage account security features
az storage account update \
  --name "stavdfslogix001" \
  --resource-group "rg-avd" \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
```

### Compliance and Auditing

#### Enable Audit Logs
```powershell
# Enable diagnostics for compliance
az monitor diagnostic-settings create \
  --name "avd-audit" \
  --resource "/subscriptions/xxx/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-avd" \
  --workspace "/subscriptions/xxx/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/la-compliance" \
  --logs '[{"category":"Connection","enabled":true},{"category":"Management","enabled":true},{"category":"Feed","enabled":true}]'
```

## 💰 Cost Optimization

### VM Right-Sizing Recommendations

| User Type | Concurrent Sessions | Recommended VM Size | Monthly Cost (per VM) |
|-----------|--------------------|--------------------|----------------------|
| **Light Users** (Office, Web) | 15-20 | D4s_v3 (4 vCPU, 16GB) | ~$280 |
| **Standard Users** (Office, LOB Apps) | 10-15 | D8s_v3 (8 vCPU, 32GB) | ~$560 |
| **Power Users** (Design, Dev) | 5-8 | D16s_v3 (16 vCPU, 64GB) | ~$1120 |
| **GPU Workloads** (CAD, 3D) | 2-4 | NV12s_v3 (12 vCPU, 112GB, GPU) | ~$2800 |

### Auto-shutdown Policies
```powershell
# Configure auto-shutdown for cost savings
az vm auto-shutdown enable \
  --name "avd-vm-001" \
  --resource-group "rg-avd" \
  --time "1900" \
  --timezone "Pacific Standard Time" \
  --notification-email "admin@company.com"
```

### Storage Cost Optimization
```powershell
# Use lifecycle management for FSLogix profiles
az storage account management-policy create \
  --account-name "stavdfslogix001" \
  --resource-group "rg-avd" \
  --policy '{
    "rules": [{
      "name": "fslogix-lifecycle",
      "type": "Lifecycle",
      "definition": {
        "filters": {"blobTypes": ["blockBlob"]},
        "actions": {
          "baseBlob": {
            "tierToCool": {"daysAfterModificationGreaterThan": 30},
            "tierToArchive": {"daysAfterModificationGreaterThan": 90}
          }
        }
      }
    }]
  }'
```

### Reserved Instances
```powershell
# Purchase reserved instances for predictable workloads
# 1-year or 3-year commitments can save 40-60%
# Best for stable, always-on environments
az reservations reservation-order purchase \
  --reservation-order-id "reservation-order-id" \
  --body '{
    "sku": {"name": "Standard_D4s_v3"},
    "location": "westus2", 
    "quantity": 10,
    "term": "P1Y",
    "billing-scope": "/subscriptions/subscription-id"
  }'
```

### Cost Monitoring
```powershell
# Set up cost alerts
az consumption budget create \
  --budget-name "AVD-Monthly-Budget" \
  --amount 10000 \
  --time-grain Monthly \
  --start-date "2024-01-01" \
  --end-date "2024-12-31" \
  --resource-group "rg-avd" \
  --notifications '[{
    "enabled": true,
    "threshold": 80,
    "operator": "GreaterThan",
    "contact-emails": ["admin@company.com"],
    "contact-roles": ["Owner"]
  }]'
```

## 📚 Additional Resources

### Microsoft Documentation
- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/en-us/azure/virtual-desktop/)
- [FSLogix Documentation](https://docs.microsoft.com/en-us/fslogix/)
- [MSIX App Attach](https://docs.microsoft.com/en-us/azure/virtual-desktop/app-attach-overview)

### Best Practices Guides
- [AVD Architecture Best Practices](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop)
- [FSLogix Best Practices](https://docs.microsoft.com/en-us/fslogix/best-practices)
- [Azure Virtual Desktop Security](https://docs.microsoft.com/en-us/azure/virtual-desktop/security-guide)

### Community Resources
- [AVD Community](https://techcommunity.microsoft.com/t5/azure-virtual-desktop/bd-p/AzureVirtualDesktop)
- [AVD GitHub Samples](https://github.com/Azure/RDS-Templates)

## 🆘 Support

### Getting Help
1. **Check this README** for common solutions
2. **Run health check**: `.\monitor-avd-azcli.ps1`
3. **Review Azure Activity Logs** in the portal  
4. **Check Microsoft Docs** for latest updates
5. **Post in AVD Community** for community support

### Filing Issues
When reporting issues, please include:
- Deployment configuration (main.parameters.json)
- Error messages from Azure CLI or portal
- Output from health check script
- Azure subscription ID and region

---

**🎯 Ready to Deploy?** Start with the [Quick Start](#-quick-start) section and have your Azure Virtual Desktop environment running in minutes!

**💡 Need Help?** Check the [Troubleshooting](#-troubleshooting) section or run the health monitoring script for automated diagnostics.

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