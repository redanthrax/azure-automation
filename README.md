# Azure Automation

**Deploy Lighthouse ARM Template (Original)**
Deploy the original ARM template for our lighthouse.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FLighthouse%2FDeployArmTemplate.json)

**Deploy Updated Lighthouse ARM Template (with AKS Permissions)**
Deploy the updated ARM template with additional roles required for AKS deployments:
- **Network Contributor**: Required for load balancer and public IP management
- **Managed Identity Operator**: Required for AKS managed identity operations

> ⚠️ **Important**: Use this template when you need to deploy AKS clusters or resolve load balancer assignment issues.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FUpdateLighthouseRoles.json)

**Alternative: Assign AKS Roles Only**
If the Lighthouse update fails, use this simpler template to just add the missing AKS roles:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Fmaster%2FAssignAKSRoles.json)

---

## When to Use Each Template

| **Template** | **Use Case** | **Additional Permissions** |
|--------------|--------------|----------------------------|
| **Original** | Standard Azure management, VM deployment, basic services | Contributor, User Access Administrator |
| **Updated (AKS)** | AKS deployments, load balancer issues, network-intensive workloads | + Network Contributor, Managed Identity Operator |

**Deploy Azure Virtual Desktop Environment**
This will deploy a Windows 11 Multisession SSO environment complete with Session Pool and Desktop Application.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fredanthrax%2Fazure-automation%2Frefs%2Fheads%2Fmaster%2FAzureVirtualDesktop%2Fmain.bicep)

### Manual Deployment

**Original Lighthouse Template:**
```bash
az deployment sub create --location 'westus2' --template-file Lighthouse/DeployArmTemplate.json
```

**Updated Lighthouse Template (with AKS permissions):**
```bash
az deployment sub create --location 'westus2' --template-file UpdateLighthouseRoles.json
```

**AKS Roles Only (Alternative):**
```bash
az deployment sub create --location 'westus2' --template-file AssignAKSRoles.json
```

**Azure Virtual Desktop:**
```bash
az deployment sub create --location 'westus2' --template-file AzureVirtualDesktop\main.bicep
```
