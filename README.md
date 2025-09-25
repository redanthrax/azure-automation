# Azure Automation

**Deploy Comprehensive Lighthouse ARM Template**
Deploy the comprehensive ARM template that includes all permissions needed for Azure management:

- **Contributor**: Full resource management permissions
- **User Access Administrator**: Role assignment permissions (includes Microsoft.Authorization/roleAssignments/write)
- **Network Contributor**: Load balancer and networking permissions for AKS
- **Managed Identity Operator**: Managed identity operations for AKS
- **Delegated Roles**: Ability to assign Contributor, Network Contributor, Managed Identity Operator, and AcrPull roles


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FLighthouseComprehensive.json)

**Deploy Azure Virtual Desktop Environment**
This will deploy a Windows 11 Multisession SSO environment complete with Session Pool and Desktop Application.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Frefs%2Fheads%2Fmaster%2FAzureVirtualDesktop%2Fmain.bicep)

### Manual Deployment

**Comprehensive Lighthouse Template:**
```bash
az deployment sub create --location 'westus2' --template-file LighthouseComprehensive.json
```

**Azure Virtual Desktop:**
```bash
az deployment sub create --location 'westus2' --template-file AzureVirtualDesktop\main.bicep
```
