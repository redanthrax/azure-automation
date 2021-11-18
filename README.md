

az login
az account set --subscription "Microsoft Azure Sponsorship"
az deployment group create --resource-group RESOURCEGROUP --template-file main.bicep