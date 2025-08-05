# Test AVD FSLogix Deployment with Host Pool Registration
# This script tests the fixed deployment to ensure session hosts are properly registered

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "AVD-TEST",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "westus2",
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "main.bicep",
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "main.parameters.json"
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVD FSLogix Deployment Test ===" -ForegroundColor Green
Write-Host "This script will test the fixed deployment configuration" -ForegroundColor Yellow

# Check Azure CLI
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
}
catch {
    Write-Error "❌ Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

# Check authentication
Write-Host "`nChecking Azure CLI authentication..." -ForegroundColor Yellow
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged into Azure CLI. Please login..." -ForegroundColor Red
    az login
    $account = az account show --output json | ConvertFrom-Json
}

Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "✅ Current subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# Set subscription if provided
if ($SubscriptionId -and $SubscriptionId -ne $account.id) {
    Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
}

# Validate Bicep template
Write-Host "`n=== Validating Bicep Template ===" -ForegroundColor Cyan
try {
    Write-Host "Validating deployment..." -ForegroundColor Yellow
    $validationResult = az deployment sub validate `
        --location $Location `
        --template-file $TemplateFile `
        --parameters $ParametersFile `
        --output json | ConvertFrom-Json
    
    if ($validationResult.error) {
        Write-Error "❌ Template validation failed: $($validationResult.error.message)"
        exit 1
    }
    
    Write-Host "✅ Template validation successful!" -ForegroundColor Green
}
catch {
    Write-Error "❌ Template validation failed: $_"
    exit 1
}

# Deploy or validate only
$deployChoice = Read-Host "`nDo you want to proceed with actual deployment? (y/N)"
if ($deployChoice -eq 'y' -or $deployChoice -eq 'Y') {
    Write-Host "`n=== Starting Deployment ===" -ForegroundColor Cyan
    
    $deploymentName = "avd-fslogix-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        Write-Host "Starting deployment: $deploymentName" -ForegroundColor Yellow
        $deployment = az deployment sub create `
            --name $deploymentName `
            --location $Location `
            --template-file $TemplateFile `
            --parameters $ParametersFile `
            --output json | ConvertFrom-Json
        
        Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
        Write-Host "Deployment Name: $deploymentName" -ForegroundColor Blue
        
        # Show outputs
        if ($deployment.properties.outputs) {
            Write-Host "`n=== Deployment Outputs ===" -ForegroundColor Cyan
            $deployment.properties.outputs | ConvertTo-Json -Depth 3
        }
    }
    catch {
        Write-Error "❌ Deployment failed: $_"
        exit 1
    }
    
    # Wait and check session host registration
    Write-Host "`n=== Checking Session Host Registration ===" -ForegroundColor Cyan
    Write-Host "Waiting 5 minutes for session host registration to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 300
    
    try {
        $hostPoolName = "hp-avd-test"  # From parameters file
        Write-Host "Checking session hosts in host pool: $hostPoolName" -ForegroundColor Yellow
        
        $sessionHosts = az desktopvirtualization session-host list `
            --host-pool-name $hostPoolName `
            --resource-group $ResourceGroupName `
            --output json | ConvertFrom-Json
        
        if ($sessionHosts -and $sessionHosts.Count -gt 0) {
            Write-Host "✅ Found $($sessionHosts.Count) session host(s) registered!" -ForegroundColor Green
            foreach ($sessionHost in $sessionHosts) {
                Write-Host "  - $($sessionHost.name): Status = $($sessionHost.status), Update State = $($sessionHost.updateState)" -ForegroundColor Blue
            }
        } else {
            Write-Warning "⚠️  No session hosts found. Check VM extensions and logs."
        }
    }
    catch {
        Write-Warning "⚠️  Could not check session host status: $_"
        Write-Host "You can manually check using: az desktopvirtualization session-host list --host-pool-name hp-avd-test --resource-group AVD-TEST" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Template validation completed. Deployment skipped." -ForegroundColor Green
    Write-Host "To deploy later, run:" -ForegroundColor Yellow
    Write-Host "az deployment sub create --name avd-fslogix-deploy --location $Location --template-file $TemplateFile --parameters $ParametersFile" -ForegroundColor Blue
}

Write-Host "`n=== Deployment Test Complete ===" -ForegroundColor Green
