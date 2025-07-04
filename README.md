# Azure Automation

**Deploy Lighthouse ARM Template**
Deploy the ARM template for our lighthouse.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FLighthouse%2FDeployArmTemplate.json)

**Deploy Azure Virtual Desktop Environment**
This will deploy a Windows 11 Multisession SSO environment complete with Session Pool and Desktop Application.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Frefs%2Fheads%2Fmaster%2FAzureVirtualDesktop%2Fmain.bicep)

### Manual Deployment

```
az deployment sub create --location 'westus2' --template-file AzureVirtualDesktop\main.bicep
```