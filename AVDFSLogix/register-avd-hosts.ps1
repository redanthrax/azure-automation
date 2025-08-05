# Post-Deployment AVD Host Registration Script
# This script registers session hosts with the AVD host pool after deployment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "AVD-TEST",
    
    [Parameter(Mandatory = $false)]
    [string]$HostPoolName = "hp-avd-test",
    
    [Parameter(Mandatory = $false)]
    [string]$VMNamePrefix = "avd0805"
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVD Host Registration Script ===" -ForegroundColor Green
Write-Host "This script will register session hosts with the host pool after deployment" -ForegroundColor Yellow

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "✅ Subscription: $($account.name)" -ForegroundColor Green

# Check if resource group exists
try {
    $rg = az group show --name $ResourceGroupName --output json | ConvertFrom-Json
    Write-Host "✅ Resource Group: $($rg.name) in $($rg.location)" -ForegroundColor Green
} catch {
    Write-Error "❌ Resource group '$ResourceGroupName' not found"
    exit 1
}

# Check if host pool exists
try {
    $hostPool = az desktopvirtualization hostpool show --name $HostPoolName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    Write-Host "✅ Host Pool: $($hostPool.name) ($($hostPool.hostPoolType))" -ForegroundColor Green
} catch {
    Write-Error "❌ Host pool '$HostPoolName' not found"
    exit 1
}

# Get VMs in the resource group
Write-Host "`n=== Finding Session Host VMs ===" -ForegroundColor Cyan
try {
    $vms = az vm list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    $sessionHostVMs = $vms | Where-Object { $_.name -like "$VMNamePrefix*" }
    
    if ($sessionHostVMs.Count -eq 0) {
        Write-Error "❌ No VMs found with prefix '$VMNamePrefix' in resource group '$ResourceGroupName'"
        exit 1
    }
    
    Write-Host "✅ Found $($sessionHostVMs.Count) session host VM(s):" -ForegroundColor Green
    foreach ($vm in $sessionHostVMs) {
        Write-Host "  - $($vm.name)" -ForegroundColor Blue
    }
} catch {
    Write-Error "❌ Failed to list VMs: $($_.Exception.Message)"
    exit 1
}

# Check VM power states and Azure AD join status
Write-Host "`n=== Checking VM Status ===" -ForegroundColor Cyan
$readyVMs = @()

foreach ($vm in $sessionHostVMs) {
    Write-Host "`n🖥️  Checking VM: $($vm.name)" -ForegroundColor White
    
    # Check power state
    $powerState = az vm get-instance-view --name $vm.name --resource-group $ResourceGroupName --query "instanceView.statuses[1].displayStatus" --output tsv
    Write-Host "   Power State: $powerState" -ForegroundColor Blue
    
    if ($powerState -ne "VM running") {
        Write-Host "   ⚠️  VM is not running - starting VM..." -ForegroundColor Yellow
        az vm start --name $vm.name --resource-group $ResourceGroupName --no-wait
        Write-Host "   🔄 VM start initiated" -ForegroundColor Yellow
        continue
    }
    
    # Check Azure AD join extension
    $extensions = az vm extension list --resource-group $ResourceGroupName --vm-name $vm.name --output json | ConvertFrom-Json
    $aadExtension = $extensions | Where-Object { $_.name -eq "AADLoginForWindows" }
    
    if ($aadExtension) {
        Write-Host "   Azure AD Join: $($aadExtension.provisioningState)" -ForegroundColor $(if ($aadExtension.provisioningState -eq "Succeeded") { "Green" } else { "Red" })
        if ($aadExtension.provisioningState -eq "Succeeded") {
            $readyVMs += $vm
        }
    } else {
        Write-Host "   ❌ Azure AD Join extension not found" -ForegroundColor Red
    }
}

if ($readyVMs.Count -eq 0) {
    Write-Host "`n❌ No VMs are ready for AVD registration" -ForegroundColor Red
    Write-Host "   Please ensure VMs are running and Azure AD joined" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✅ $($readyVMs.Count) VM(s) ready for AVD registration" -ForegroundColor Green

# Get registration token
Write-Host "`n=== Getting Registration Token ===" -ForegroundColor Cyan
try {
    # Try to get existing registration token first
    $existingToken = az desktopvirtualization hostpool retrieve-registration-token --name $HostPoolName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    
    if ($existingToken -and $existingToken.token) {
        Write-Host "✅ Using existing registration token" -ForegroundColor Green
        $registrationToken = $existingToken.token
    } else {
        Write-Host "⚠️  No existing token found, this feature may not be available in Azure CLI" -ForegroundColor Yellow
        Write-Host "   Will use PowerShell approach instead..." -ForegroundColor Yellow
        
        # Generate new registration token using PowerShell
        $registrationScript = @"
try {
    Import-Module Az.Accounts -Force
    Import-Module Az.DesktopVirtualization -Force
    
    # Connect using Azure CLI credentials
    `$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    Connect-AzAccount -AccountId `$context.Account.Id -TenantId `$context.Tenant.Id -AccessToken `$context.TokenCache.ReadItems()[0].AccessToken -Scope 'https://management.azure.com/'
    
    # Create registration token
    `$token = New-AzWvdRegistrationInfo -ResourceGroupName '$ResourceGroupName' -HostPoolName '$HostPoolName' -ExpirationTime (Get-Date).AddHours(2)
    Write-Output `$token.Token
} catch {
    Write-Error "Failed to generate registration token: `$(`$_.Exception.Message)"
    exit 1
}
"@
        
        $registrationToken = powershell -Command $registrationScript
        if (-not $registrationToken) {
            Write-Error "❌ Failed to generate registration token"
            exit 1
        }
        Write-Host "✅ Generated new registration token" -ForegroundColor Green
    }
} catch {
    Write-Error "❌ Failed to get registration token: $($_.Exception.Message)"
    exit 1
}

# Install AVD agents on ready VMs
Write-Host "`n=== Installing AVD Agents ===" -ForegroundColor Cyan

foreach ($vm in $readyVMs) {
    Write-Host "`n🔧 Installing AVD Agent on: $($vm.name)" -ForegroundColor White
    
    $avdInstallScript = @"
try {
    Write-Host 'Starting AVD Agent installation...'
    
    # Download AVD Agent
    `$agentUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
    `$bootUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
    
    Write-Host 'Downloading AVD Agent...'
    Invoke-WebRequest -Uri `$agentUrl -OutFile 'C:\AVDAgent.msi'
    
    Write-Host 'Installing AVD Agent...'
    Start-Process msiexec -ArgumentList '/i C:\AVDAgent.msi /quiet REGISTRATIONTOKEN=$registrationToken' -Wait
    
    Write-Host 'Downloading AVD Boot Loader...'
    Invoke-WebRequest -Uri `$bootUrl -OutFile 'C:\AVDBootLoader.msi'
    
    Write-Host 'Installing AVD Boot Loader...'
    Start-Process msiexec -ArgumentList '/i C:\AVDBootLoader.msi /quiet' -Wait
    
    Write-Host 'AVD Agent installation completed successfully'
} catch {
    Write-Error "Failed to install AVD Agent: `$(`$_.Exception.Message)"
    exit 1
}
"@
    
    try {
        # Remove any existing AVD registration extension
        $existingExtensions = az vm extension list --resource-group $ResourceGroupName --vm-name $vm.name --output json | ConvertFrom-Json
        $avdExtension = $existingExtensions | Where-Object { $_.name -eq "AVDHostRegistration" }
        if ($avdExtension) {
            Write-Host "   🗑️  Removing existing AVD extension..." -ForegroundColor Yellow
            az vm extension delete --resource-group $ResourceGroupName --vm-name $vm.name --name "AVDHostRegistration" --no-wait
            Start-Sleep -Seconds 10
        }
        
        # Install new extension
        Write-Host "   📦 Installing AVD Agent via custom script extension..." -ForegroundColor Yellow
        az vm extension set `
            --resource-group $ResourceGroupName `
            --vm-name $vm.name `
            --name "AVDHostRegistration" `
            --publisher "Microsoft.Compute" `
            --version "1.10" `
            --settings '{}' `
            --protected-settings "{`"commandToExecute`": `"powershell -ExecutionPolicy Unrestricted -Command `"$avdInstallScript`"`"}" `
            --no-wait
        
        Write-Host "   ✅ AVD Agent installation initiated" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to install AVD Agent: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Waiting for Installation to Complete ===" -ForegroundColor Cyan
Write-Host "Waiting 3 minutes for AVD agent installations to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 180

# Check results
Write-Host "`n=== Checking Registration Results ===" -ForegroundColor Cyan

# Check extension status
foreach ($vm in $readyVMs) {
    Write-Host "`n🔍 Checking: $($vm.name)" -ForegroundColor White
    
    $extensions = az vm extension list --resource-group $ResourceGroupName --vm-name $vm.name --output json | ConvertFrom-Json
    $avdExtension = $extensions | Where-Object { $_.name -eq "AVDHostRegistration" }
    
    if ($avdExtension) {
        Write-Host "   AVD Extension Status: $($avdExtension.provisioningState)" -ForegroundColor $(if ($avdExtension.provisioningState -eq "Succeeded") { "Green" } else { "Red" })
    } else {
        Write-Host "   ❌ AVD extension not found" -ForegroundColor Red
    }
}

# Use our comprehensive session host checker
Write-Host "`n=== Final Registration Check ===" -ForegroundColor Cyan
try {
    .\check-session-hosts.ps1 -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
} catch {
    Write-Host "⚠️  Could not run session host checker: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== AVD Host Registration Complete ===" -ForegroundColor Green
Write-Host "If session hosts are not showing up, check:" -ForegroundColor Yellow
Write-Host "  1. VM extension logs in Azure portal" -ForegroundColor Yellow
Write-Host "  2. VM event logs for AVD agent installation" -ForegroundColor Yellow
Write-Host "  3. Network connectivity from VMs to AVD endpoints" -ForegroundColor Yellow
