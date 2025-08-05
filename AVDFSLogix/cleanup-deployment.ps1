# Cleanup AVD FSLogix Deployment
# This script removes all resources created by the AVD FSLogix deployment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "AVD-TEST",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVD FSLogix Deployment Cleanup ===" -ForegroundColor Red

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "✅ Subscription: $($account.name)" -ForegroundColor Green

# Check if resource group exists
$rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
if (-not $rg) {
    Write-Host "✅ Resource group '$ResourceGroupName' doesn't exist - nothing to clean up" -ForegroundColor Green
    return
}

Write-Host "`n⚠️  This will DELETE the following resource group and ALL its contents:" -ForegroundColor Yellow
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "   Location: $($rg.location)" -ForegroundColor Yellow

# List resources that will be deleted
Write-Host "`n📋 Resources that will be deleted:" -ForegroundColor Cyan
try {
    $resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    if ($resources -and $resources.Count -gt 0) {
        foreach ($resource in $resources) {
            Write-Host "   - $($resource.name) ($($resource.type))" -ForegroundColor White
        }
        Write-Host "   Total: $($resources.Count) resources" -ForegroundColor Blue
    } else {
        Write-Host "   No resources found in the resource group" -ForegroundColor Blue
    }
}
catch {
    Write-Warning "Could not list resources: $_"
}

if (-not $Force) {
    $confirmation = Read-Host "`n❓ Are you sure you want to delete this resource group and all its contents? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
        return
    }
}

Write-Host "`n🗑️  Deleting resource group '$ResourceGroupName'..." -ForegroundColor Red
try {
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "✅ Resource group deletion initiated" -ForegroundColor Green
    Write-Host "   The deletion will continue in the background" -ForegroundColor Blue
    Write-Host "   You can check the status in the Azure portal" -ForegroundColor Blue
}
catch {
    Write-Error "❌ Failed to delete resource group: $_"
    exit 1
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green
