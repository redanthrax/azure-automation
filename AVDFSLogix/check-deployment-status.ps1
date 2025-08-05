# AVD FSLogix Deployment Status Check
# This script checks the current status of your AVD deployment and session host registration

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "AVD-TEST",
    
    [Parameter(Mandatory = $false)]
    [string]$HostPoolName = "hp-avd-test"
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVD FSLogix Deployment Status Check ===" -ForegroundColor Green

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "✅ Subscription: $($account.name)" -ForegroundColor Green

Write-Host "`n=== Checking Resource Group ===" -ForegroundColor Cyan
try {
    $rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($rg) {
        Write-Host "✅ Resource Group '$ResourceGroupName' exists in $($rg.location)" -ForegroundColor Green
    } else {
        Write-Host "❌ Resource Group '$ResourceGroupName' not found" -ForegroundColor Red
        return
    }
}
catch {
    Write-Host "❌ Resource Group '$ResourceGroupName' not found" -ForegroundColor Red
    return
}

Write-Host "`n=== Checking AVD Host Pool ===" -ForegroundColor Cyan
try {
    $hostPool = az desktopvirtualization hostpool show --name $HostPoolName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($hostPool) {
        Write-Host "✅ Host Pool '$HostPoolName' exists" -ForegroundColor Green
        Write-Host "  - Type: $($hostPool.hostPoolType)" -ForegroundColor Blue
        Write-Host "  - Load Balancer: $($hostPool.loadBalancerType)" -ForegroundColor Blue
        Write-Host "  - Max Sessions: $($hostPool.maxSessionLimit)" -ForegroundColor Blue
        Write-Host "  - Friendly Name: $($hostPool.friendlyName)" -ForegroundColor Blue
    } else {
        Write-Host "❌ Host Pool '$HostPoolName' not found" -ForegroundColor Red
        return
    }
}
catch {
    Write-Host "❌ Host Pool '$HostPoolName' not found" -ForegroundColor Red
    return
}

Write-Host "`n=== Checking Session Hosts ===" -ForegroundColor Cyan
try {
    $sessionHosts = az desktopvirtualization session-host list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($sessionHosts -and $sessionHosts.Count -gt 0) {
        Write-Host "✅ Found $($sessionHosts.Count) session host(s):" -ForegroundColor Green
        foreach ($sessionHost in $sessionHosts) {
            $status = $sessionHost.status
            $updateState = $sessionHost.updateState
            $allowNewSessions = $sessionHost.allowNewSession
            $sessions = $sessionHost.sessions
            
            $statusColor = switch ($status) {
                "Available" { "Green" }
                "Unavailable" { "Red" }
                "Upgrading" { "Yellow" }
                default { "Blue" }
            }
            
            Write-Host "  📱 $($sessionHost.name)" -ForegroundColor White
            Write-Host "    Status: $status" -ForegroundColor $statusColor
            Write-Host "    Update State: $updateState" -ForegroundColor Blue
            Write-Host "    Allow New Sessions: $allowNewSessions" -ForegroundColor Blue
            Write-Host "    Active Sessions: $sessions" -ForegroundColor Blue
            Write-Host "    Agent Version: $($sessionHost.agentVersion)" -ForegroundColor Blue
        }
    } else {
        Write-Host "❌ No session hosts found in host pool" -ForegroundColor Red
        Write-Host "   This indicates the hosts are not properly registered with the host pool" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Could not retrieve session hosts: $_" -ForegroundColor Red
}

Write-Host "`n=== Checking Virtual Machines ===" -ForegroundColor Cyan
try {
    $vms = az vm list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($vms -and $vms.Count -gt 0) {
        Write-Host "✅ Found $($vms.Count) virtual machine(s):" -ForegroundColor Green
        foreach ($vm in $vms) {
            Write-Host "  🖥️  $($vm.name)" -ForegroundColor White
            Write-Host "    Size: $($vm.hardwareProfile.vmSize)" -ForegroundColor Blue
            Write-Host "    OS: $($vm.storageProfile.osDisk.osType)" -ForegroundColor Blue
            Write-Host "    Provisioning State: $($vm.provisioningState)" -ForegroundColor Blue
            
            # Check power state
            $vmStatus = az vm get-instance-view --name $vm.name --resource-group $ResourceGroupName --query "instanceView.statuses[1].displayStatus" --output tsv 2>$null
            if ($vmStatus) {
                Write-Host "    Power State: $vmStatus" -ForegroundColor Blue
            }
        }
    } else {
        Write-Host "❌ No virtual machines found in resource group" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Could not retrieve virtual machines: $_" -ForegroundColor Red
}

Write-Host "`n=== Checking Storage Account ===" -ForegroundColor Cyan
try {
    $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if ($storageAccounts -and $storageAccounts.Count -gt 0) {
        Write-Host "✅ Found $($storageAccounts.Count) storage account(s):" -ForegroundColor Green
        foreach ($storage in $storageAccounts) {
            Write-Host "  💾 $($storage.name)" -ForegroundColor White
            Write-Host "    Kind: $($storage.kind)" -ForegroundColor Blue
            Write-Host "    Tier: $($storage.sku.tier)" -ForegroundColor Blue
            Write-Host "    Replication: $($storage.sku.name)" -ForegroundColor Blue
        }
    } else {
        Write-Host "❌ No storage accounts found" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Could not retrieve storage accounts: $_" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($hostPool -and $sessionHosts -and $sessionHosts.Count -gt 0) {
    Write-Host "✅ AVD deployment appears to be working correctly!" -ForegroundColor Green
    Write-Host "   Host pool exists and has registered session hosts" -ForegroundColor Green
} elseif ($hostPool -and (!$sessionHosts -or $sessionHosts.Count -eq 0)) {
    Write-Host "⚠️  Partial deployment detected:" -ForegroundColor Yellow
    Write-Host "   - Host pool exists" -ForegroundColor Yellow
    Write-Host "   - But no session hosts are registered" -ForegroundColor Yellow
    Write-Host "   - This suggests the VM extensions failed to register the hosts" -ForegroundColor Yellow
    Write-Host "`n🔧 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Check VM extension status" -ForegroundColor White
    Write-Host "   2. Review VM logs for AVD agent installation" -ForegroundColor White
    Write-Host "   3. Ensure registration token is valid" -ForegroundColor White
    Write-Host "   4. Redeploy with fixed configuration" -ForegroundColor White
} else {
    Write-Host "❌ AVD deployment appears to be incomplete or failed" -ForegroundColor Red
    Write-Host "   Host pool and/or session hosts are missing" -ForegroundColor Red
}

Write-Host "`n=== Status Check Complete ===" -ForegroundColor Green
