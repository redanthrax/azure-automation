# AVD Health Monitoring using Azure CLI
# This script provides health monitoring capabilities for Azure Virtual Desktop

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspace,
    
    [Parameter(Mandatory = $false)]
    [int]$Hours = 24
)

$ErrorActionPreference = "Stop"

Write-Host "AVD Health Monitoring using Azure CLI" -ForegroundColor Green
Write-Host "Monitoring host pool: $HostPoolName" -ForegroundColor Yellow

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

# Function to display status with color coding
function Show-Status {
    param(
        [string]$Component,
        [string]$Status,
        [string]$Details = ""
    )
    
    $color = switch ($Status) {
        "Healthy" { "Green" }
        "Warning" { "Yellow" }
        "Critical" { "Red" }
        default { "White" }
    }
    
    Write-Host "[$Status] " -ForegroundColor $color -NoNewline
    Write-Host "$Component" -ForegroundColor White -NoNewline
    if ($Details) {
        Write-Host " - $Details" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

Write-Host "`n=== AVD Environment Health Check ===" -ForegroundColor Cyan

# 1. Host Pool Status
Write-Host "`n1. Host Pool Status" -ForegroundColor Blue
try {
    $hostPool = az desktopvirtualization hostpool show --name $HostPoolName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    if ($hostPool) {
        Show-Status "Host Pool" "Healthy" "Type: $($hostPool.hostPoolType), Load Balancer: $($hostPool.loadBalancerType)"
        Write-Host "   Max Sessions: $($hostPool.maxSessionLimit)" -ForegroundColor Gray
        Write-Host "   Registration Token Valid: $($hostPool.registrationInfo.expirationTime -gt (Get-Date))" -ForegroundColor Gray
    }
}
catch {
    Show-Status "Host Pool" "Critical" "Failed to retrieve host pool information"
}

# 2. Session Hosts Status
Write-Host "`n2. Session Hosts Status" -ForegroundColor Blue
try {
    # Get subscription ID for REST API call
    $subscriptionId = az account show --query id --output tsv
    $sessionHostsUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/sessionHosts?api-version=2023-09-05"
    $sessionHostsResult = az rest --method GET --uri $sessionHostsUri --output json | ConvertFrom-Json
    $sessionHosts = $sessionHostsResult.value
    
    if ($sessionHosts.Count -eq 0) {
        Show-Status "Session Hosts" "Warning" "No session hosts registered (VMs may not be domain-joined or AVD agent not installed)"
    } else {
        $healthyHosts = ($sessionHosts | Where-Object { $_.properties.status -eq "Available" }).Count
        $totalHosts = $sessionHosts.Count
        
        if ($healthyHosts -eq $totalHosts) {
            Show-Status "Session Hosts" "Healthy" "$healthyHosts/$totalHosts hosts available"
        } elseif ($healthyHosts -gt 0) {
            Show-Status "Session Hosts" "Warning" "$healthyHosts/$totalHosts hosts available"
        } else {
            Show-Status "Session Hosts" "Critical" "No hosts available"
        }
        
        # Show individual host status
        foreach ($sessionHost in $sessionHosts) {
            $sessionHostStatus = switch ($sessionHost.properties.status) {
                "Available" { "Healthy" }
                "Unavailable" { "Critical" }
                "Shutdown" { "Warning" }
                default { "Warning" }
            }
            $hostName = $sessionHost.name.Split('/')[-1]  # Extract host name from full resource name
            Show-Status "  $hostName" $sessionHostStatus "Status: $($sessionHost.properties.status), Sessions: $($sessionHost.properties.sessions)"
        }
    }
}
catch {
    Show-Status "Session Hosts" "Critical" "Failed to retrieve session host information"
}

# 3. Active Sessions
Write-Host "`n3. Active Sessions" -ForegroundColor Blue
try {
    # Get subscription ID for REST API call
    $subscriptionId = az account show --query id --output tsv
    $sessionsUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/userSessions?api-version=2023-09-05"
    $sessionsResult = az rest --method GET --uri $sessionsUri --output json | ConvertFrom-Json
    $sessions = $sessionsResult.value
    
    if ($sessions.Count -eq 0) {
        Show-Status "Active Sessions" "Healthy" "No active sessions"
    } else {
        Show-Status "Active Sessions" "Healthy" "$($sessions.Count) active sessions"
        
        # Show session details
        foreach ($session in $sessions) {
            $sessionName = $session.name.Split('/')[-1]  # Extract session name from full resource name
            Write-Host "   User: $($session.properties.userPrincipalName), Session: $sessionName, State: $($session.properties.sessionState)" -ForegroundColor Gray
        }
    }
}
catch {
    Show-Status "Active Sessions" "Warning" "Failed to retrieve session information"
}

# 4. Storage Account Status (FSLogix)
Write-Host "`n4. Storage Account Status" -ForegroundColor Blue
try {
    # Get storage accounts in the resource group
    $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    $fslogixStorage = $storageAccounts | Where-Object { $_.name -like "*fslogix*" -or $_.name -like "*avd*" }
    
    if ($fslogixStorage) {
        foreach ($storage in $fslogixStorage) {
            $storageStatus = if ($storage.statusOfPrimary -eq "available") { "Healthy" } else { "Critical" }
            Show-Status "Storage: $($storage.name)" $storageStatus "Status: $($storage.statusOfPrimary), SKU: $($storage.sku.name)"
            
            # Check file shares
            $shares = az storage share list --account-name $storage.name --output json 2>$null | ConvertFrom-Json
            if ($shares) {
                foreach ($share in $shares) {
                    Write-Host "   File Share: $($share.name)" -ForegroundColor Gray
                }
            }
        }
    } else {
        Show-Status "FSLogix Storage" "Warning" "No FSLogix storage accounts found"
    }
}
catch {
    Show-Status "Storage Account" "Warning" "Failed to retrieve storage information"
}

# 5. Virtual Machine Status
Write-Host "`n5. Virtual Machine Status" -ForegroundColor Blue
try {
    $vms = az vm list --resource-group $ResourceGroupName --show-details --output json | ConvertFrom-Json
    $avdVMs = $vms | Where-Object { $_.name -like "*avd*" -or $_.tags.purpose -eq "AVD" }
    
    if ($avdVMs) {
        foreach ($vm in $avdVMs) {
            $vmStatus = switch ($vm.powerState) {
                "VM running" { "Healthy" }
                "VM stopped" { "Warning" }
                "VM deallocated" { "Warning" }
                default { "Critical" }
            }
            Show-Status "VM: $($vm.name)" $vmStatus "Power: $($vm.powerState), Size: $($vm.hardwareProfile.vmSize)"
        }
    } else {
        Show-Status "Virtual Machines" "Warning" "No AVD VMs found"
    }
}
catch {
    Show-Status "Virtual Machines" "Warning" "Failed to retrieve VM information"
}

# 6. Application Groups
Write-Host "`n6. Application Groups" -ForegroundColor Blue
try {
    $appGroups = az desktopvirtualization applicationgroup list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    
    if ($appGroups.Count -eq 0) {
        Show-Status "Application Groups" "Warning" "No application groups found"
    } else {
        foreach ($appGroup in $appGroups) {
            Show-Status "App Group: $($appGroup.name)" "Healthy" "Type: $($appGroup.applicationGroupType)"
            
            # Check applications in the group
            if ($appGroup.applicationGroupType -eq "RemoteApp") {
                $apps = az desktopvirtualization application list --application-group-name $appGroup.name --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
                if ($apps) {
                    Write-Host "   Applications: $($apps.Count)" -ForegroundColor Gray
                }
            }
        }
    }
}
catch {
    Show-Status "Application Groups" "Warning" "Failed to retrieve application group information"
}

# 7. Log Analytics Queries (if workspace provided)
if ($LogAnalyticsWorkspace) {
    Write-Host "`n7. Log Analytics Insights" -ForegroundColor Blue
    try {
        # Query for connection errors in the last 24 hours
        $query = @"
WVDConnections
| where TimeGenerated > ago(${Hours}h)
| where State == "Failed"
| summarize FailedConnections = count() by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
"@
        
        Write-Host "Querying connection failures in last $Hours hours..." -ForegroundColor Yellow
        $results = az monitor log-analytics query --workspace $LogAnalyticsWorkspace --analytics-query $query --output json | ConvertFrom-Json
        
        if ($results.tables[0].rows.Count -eq 0) {
            Show-Status "Connection Failures" "Healthy" "No connection failures in last $Hours hours"
        } else {
            $totalFailures = ($results.tables[0].rows | Measure-Object -Property { $_[1] } -Sum).Sum
            Show-Status "Connection Failures" "Warning" "$totalFailures failures in last $Hours hours"
        }
    }
    catch {
        Show-Status "Log Analytics" "Warning" "Failed to query Log Analytics workspace"
    }
}

Write-Host "`n=== Health Check Summary ===" -ForegroundColor Cyan
$endTime = Get-Date
Write-Host "Health check completed at: $endTime" -ForegroundColor Green
Write-Host "Use the manage-avd-azcli.ps1 script to perform remediation actions." -ForegroundColor Yellow
