# Check AVD Session Host Registration Status
# This script uses alternative methods to check session host registration

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "AVD-TEST",
    
    [Parameter(Mandatory = $false)]
    [string]$HostPoolName = "hp-avd-test"
)

$ErrorActionPreference = "Stop"

Write-Host "=== AVD Session Host Registration Check ===" -ForegroundColor Green

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "✅ Subscription: $($account.name)" -ForegroundColor Green

# Method 1: Try the Azure CLI command (if available)
Write-Host "`n=== Method 1: Azure CLI ===" -ForegroundColor Cyan
try {
    # Try different variations of the session host command
    $sessionHostCommands = @(
        "az desktopvirtualization sessionhost list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output json",
        "az wvd sessionhost list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output json",
        "az avd sessionhost list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output json"
    )
    
    $sessionHosts = $null
    foreach ($cmd in $sessionHostCommands) {
        try {
            Write-Host "Trying: $cmd" -ForegroundColor Yellow
            $result = Invoke-Expression $cmd 2>$null
            if ($result) {
                $sessionHosts = $result | ConvertFrom-Json
                Write-Host "✅ Command worked!" -ForegroundColor Green
                break
            }
        } catch {
            Write-Host "❌ Command failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if ($sessionHosts -and $sessionHosts.Count -gt 0) {
        Write-Host "✅ Found $($sessionHosts.Count) session host(s):" -ForegroundColor Green
        foreach ($sessionHost in $sessionHosts) {
            Write-Host "  - $($sessionHost.name): Status = $($sessionHost.status)" -ForegroundColor Blue
        }
    } else {
        Write-Host "❌ No session hosts found via Azure CLI" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Azure CLI method failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 2: Check VM registration status indirectly
Write-Host "`n=== Method 2: VM Extension Status ===" -ForegroundColor Cyan
try {
    $vms = az vm list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    if ($vms -and $vms.Count -gt 0) {
        Write-Host "Found $($vms.Count) VM(s) in resource group:" -ForegroundColor Blue
        
        foreach ($vm in $vms) {
            Write-Host "`n🖥️  VM: $($vm.name)" -ForegroundColor White
            
            # Check VM power state
            $vmStatus = az vm get-instance-view --name $vm.name --resource-group $ResourceGroupName --query "instanceView.statuses[1].displayStatus" --output tsv 2>$null
            Write-Host "   Power State: $vmStatus" -ForegroundColor Blue
            
            # Check extensions
            $extensions = az vm extension list --resource-group $ResourceGroupName --vm-name $vm.name --output json | ConvertFrom-Json
            Write-Host "   Extensions:" -ForegroundColor Blue
            
            $aadJoinStatus = "Not Installed"
            $avdRegStatus = "Not Installed"
            $fslogixStatus = "Not Installed"
            
            foreach ($ext in $extensions) {
                switch ($ext.name) {
                    "AADLoginForWindows" { 
                        $aadJoinStatus = $ext.provisioningState
                        Write-Host "     - Azure AD Join: $aadJoinStatus" -ForegroundColor $(if ($ext.provisioningState -eq "Succeeded") { "Green" } else { "Red" })
                    }
                    "AVDHostRegistration" { 
                        $avdRegStatus = $ext.provisioningState
                        Write-Host "     - AVD Registration: $avdRegStatus" -ForegroundColor $(if ($ext.provisioningState -eq "Succeeded") { "Green" } else { "Red" })
                    }
                    "FSLogixConfiguration" { 
                        $fslogixStatus = $ext.provisioningState
                        Write-Host "     - FSLogix Config: $fslogixStatus" -ForegroundColor $(if ($ext.provisioningState -eq "Succeeded") { "Green" } else { "Red" })
                    }
                }
            }
            
            # Overall assessment
            if ($aadJoinStatus -eq "Succeeded" -and $avdRegStatus -eq "Succeeded") {
                Write-Host "   ✅ VM should be registered with host pool" -ForegroundColor Green
            } elseif ($aadJoinStatus -ne "Succeeded") {
                Write-Host "   ❌ Azure AD Join failed - VM cannot register with host pool" -ForegroundColor Red
            } elseif ($avdRegStatus -ne "Succeeded") {
                Write-Host "   ❌ AVD Registration failed - VM not registered with host pool" -ForegroundColor Red
            } else {
                Write-Host "   ⚠️  Status unclear - check manually" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ No VMs found in resource group" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ VM check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 3: Azure Resource Graph query (if available)
Write-Host "`n=== Method 3: Azure Resource Graph ===" -ForegroundColor Cyan
try {
    $query = "resources | where type =~ 'microsoft.desktopvirtualization/hostpools/sessionhosts' | where name contains '$HostPoolName' | project name, properties"
    $sessionHostResources = az graph query -q $query --output json 2>$null | ConvertFrom-Json
    
    if ($sessionHostResources -and $sessionHostResources.data -and $sessionHostResources.data.Count -gt 0) {
        Write-Host "✅ Found $($sessionHostResources.data.Count) session host(s) via Resource Graph:" -ForegroundColor Green
        foreach ($sessionHost in $sessionHostResources.data) {
            Write-Host "  - $($sessionHost.name)" -ForegroundColor Blue
        }
    } else {
        Write-Host "❌ No session hosts found via Resource Graph" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Resource Graph query failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 4: PowerShell Az Module (if available)
Write-Host "`n=== Method 4: PowerShell Az Module ===" -ForegroundColor Cyan
try {
    Import-Module Az.DesktopVirtualization -ErrorAction SilentlyContinue
    if (Get-Module Az.DesktopVirtualization) {
        $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue
        if ($sessionHosts) {
            Write-Host "✅ Found $($sessionHosts.Count) session host(s) via PowerShell:" -ForegroundColor Green
            foreach ($sessionHost in $sessionHosts) {
                Write-Host "  - $($sessionHost.Name): Status = $($sessionHost.Status)" -ForegroundColor Blue
            }
        } else {
            Write-Host "❌ No session hosts found via PowerShell" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Az.DesktopVirtualization module not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ PowerShell method failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "If all methods show no session hosts, the likely causes are:" -ForegroundColor Yellow
Write-Host "  1. Azure AD Join extension failed (hostname conflict)" -ForegroundColor Yellow
Write-Host "  2. AVD Registration extension failed" -ForegroundColor Yellow
Write-Host "  3. Network connectivity issues during registration" -ForegroundColor Yellow
Write-Host "  4. Registration token expired or invalid" -ForegroundColor Yellow

Write-Host "`n=== Registration Check Complete ===" -ForegroundColor Green
