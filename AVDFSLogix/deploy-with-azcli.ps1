# Azure Virtual Desktop Deployment with Azure CLI
# This script replaces PowerShell modules with Azure CLI commands

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "main.bicep",
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "main.parameters.json"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting Azure Virtual Desktop deployment using Azure CLI..." -ForegroundColor Green

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Blue
}
catch {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

# Login check
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged into Azure CLI. Please login..." -ForegroundColor Red
    az login
    $account = az account show --output json | ConvertFrom-Json
}

Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "Current subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# Configure Azure CLI for preview extensions
Write-Host "Configuring Azure CLI for preview extensions..." -ForegroundColor Yellow
az config set extension.dynamic_install_allow_preview=true --only-show-errors
az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors

# Install required extensions
Write-Host "Installing required Azure CLI extensions..." -ForegroundColor Yellow
az extension add --name desktopvirtualization --only-show-errors 2>$null

# Set subscription
if ($account.id -ne $SubscriptionId) {
    Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription"
        exit 1
    }
}

# Check if resource group exists, create if it doesn't
Write-Host "Checking resource group: $ResourceGroupName" -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location --output table
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        exit 1
    }
}
else {
    Write-Host "Resource group already exists: $ResourceGroupName" -ForegroundColor Green
}

# Validate template
Write-Host "Validating Bicep template..." -ForegroundColor Yellow
az deployment sub validate `
    --location $Location `
    --template-file $TemplateFile `
    --parameters $ParametersFile `
    --parameters resourceGroupName=$ResourceGroupName `
    --parameters location=$Location `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Template validation failed"
    exit 1
}

Write-Host "Template validation successful!" -ForegroundColor Green

# Deploy template
Write-Host "Starting deployment..." -ForegroundColor Yellow
$deploymentName = "avd-fslogix-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment sub create `
    --name $deploymentName `
    --location $Location `
    --template-file $TemplateFile `
    --parameters $ParametersFile `
    --parameters resourceGroupName=$ResourceGroupName `
    --parameters location=$Location `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green

# Get deployment outputs
Write-Host "Retrieving deployment outputs..." -ForegroundColor Yellow
$outputs = az deployment sub show --name $deploymentName --query properties.outputs --output json | ConvertFrom-Json

if ($outputs) {
    Write-Host "Deployment Outputs:" -ForegroundColor Cyan
    $outputs | ConvertTo-Json -Depth 3 | Write-Host
}

# Post-deployment verification using Azure CLI
Write-Host "Verifying deployment..." -ForegroundColor Yellow

# Check host pool
$hostPoolName = (Get-Content $ParametersFile | ConvertFrom-Json).parameters.hostPoolName.value
Write-Host "Checking host pool: $hostPoolName" -ForegroundColor Blue
az desktopvirtualization hostpool show --name $hostPoolName --resource-group $ResourceGroupName --output table

# Check application group
$appGroupName = (Get-Content $ParametersFile | ConvertFrom-Json).parameters.appGroupName.value
Write-Host "Checking application group: $appGroupName" -ForegroundColor Blue
az desktopvirtualization applicationgroup show --name $appGroupName --resource-group $ResourceGroupName --output table

# Check workspace
$workspaceName = (Get-Content $ParametersFile | ConvertFrom-Json).parameters.workspaceName.value
Write-Host "Checking workspace: $workspaceName" -ForegroundColor Blue
az desktopvirtualization workspace show --name $workspaceName --resource-group $ResourceGroupName --output table

# Check storage account
$storageAccountName = (Get-Content $ParametersFile | ConvertFrom-Json).parameters.storageAccountName.value
Write-Host "Checking storage account: $storageAccountName" -ForegroundColor Blue
az storage account show --name $storageAccountName --resource-group $ResourceGroupName --output table

Write-Host "Deployment verification completed!" -ForegroundColor Green
Write-Host "Your Azure Virtual Desktop environment is ready!" -ForegroundColor Cyan
