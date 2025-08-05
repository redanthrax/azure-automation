# Azure Virtual Desktop with FSLogix Deployment Script
# This script deploys AVD resources with FSLogix storage and backup

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ParametersFile = "main.parameters.json",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2"
)

# Check if Azure PowerShell is installed
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Error "Azure PowerShell module is not installed. Please install it first: Install-Module -Name Az -Scope CurrentUser"
    exit 1
}

# Connect to Azure if not already connected
$context = Get-AzContext
if (-not $context) {
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SubscriptionId
}

# Get current subscription info
$currentSub = Get-AzContext
Write-Host "Deploying to subscription: $($currentSub.Subscription.Name) ($($currentSub.Subscription.Id))" -ForegroundColor Green

# Validate parameters file exists
if (-not (Test-Path $ParametersFile)) {
    Write-Error "Parameters file '$ParametersFile' not found!"
    exit 1
}

# Deploy the Bicep template
$deploymentName = "avd-fslogix-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "`nStarting deployment: $deploymentName" -ForegroundColor Yellow
Write-Host "Template: main.bicep" -ForegroundColor Yellow
Write-Host "Parameters: $ParametersFile" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

try {
    $deployment = New-AzSubscriptionDeployment `
        -Name $deploymentName `
        -Location $Location `
        -TemplateFile "main.bicep" `
        -TemplateParameterFile $ParametersFile `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
        
        # Display outputs
        if ($deployment.Outputs) {
            Write-Host "`n📋 Deployment Outputs:" -ForegroundColor Cyan
            $deployment.Outputs.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value.Value)" -ForegroundColor White
            }
        }
        
        Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Configure FSLogix RBAC permissions for user access" -ForegroundColor White
        Write-Host "2. Add users to the application group in Azure portal" -ForegroundColor White
        Write-Host "3. Test AVD connection with FSLogix profile redirection" -ForegroundColor White
        Write-Host "4. Verify backup is working for the file share" -ForegroundColor White
    }
    else {
        Write-Error "Deployment failed with state: $($deployment.ProvisioningState)"
        exit 1
    }
}
catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
