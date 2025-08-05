# AVD Management Operations using Azure CLI
# This script provides common management tasks for Azure Virtual Desktop

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ListSessions", "DrainMode", "RestartVM", "GetHostPoolStatus", "UpdateHostPool", "ListApplications", "AssignUsers")]
    [string]$Operation,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory = $false)]
    [string]$SessionHostName,
    
    [Parameter(Mandatory = $false)]
    [string]$ApplicationGroupName,
    
    [Parameter(Mandatory = $false)]
    [string[]]$UserPrincipalNames,
    
    [Parameter(Mandatory = $false)]
    [bool]$AllowNewSessions = $true
)

$ErrorActionPreference = "Stop"

Write-Host "AVD Management Operations using Azure CLI" -ForegroundColor Green
Write-Host "Operation: $Operation" -ForegroundColor Yellow

# Check Azure CLI authentication
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not logged into Azure CLI. Please run 'az login' first."
    exit 1
}

switch ($Operation) {
    "ListSessions" {
        if (-not $HostPoolName) {
            Write-Error "HostPoolName is required for ListSessions operation"
            exit 1
        }
        
        Write-Host "Listing active sessions for host pool: $HostPoolName" -ForegroundColor Blue
        az desktopvirtualization session list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output table
    }
    
    "DrainMode" {
        if (-not $HostPoolName -or -not $SessionHostName) {
            Write-Error "HostPoolName and SessionHostName are required for DrainMode operation"
            exit 1
        }
        
        $drainMode = if ($AllowNewSessions) { "false" } else { "true" }
        Write-Host "Setting drain mode to $drainMode for session host: $SessionHostName" -ForegroundColor Blue
        
        az desktopvirtualization sessionhost update `
            --host-pool-name $HostPoolName `
            --resource-group $ResourceGroupName `
            --name $SessionHostName `
            --allow-new-session $AllowNewSessions `
            --output table
    }
    
    "RestartVM" {
        if (-not $SessionHostName) {
            Write-Error "SessionHostName is required for RestartVM operation"
            exit 1
        }
        
        # Extract VM name from session host name (remove domain suffix)
        $vmName = $SessionHostName.Split('.')[0]
        
        Write-Host "Restarting VM: $vmName" -ForegroundColor Blue
        az vm restart --name $vmName --resource-group $ResourceGroupName --output table
        
        Write-Host "VM restart initiated. Checking status..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        az vm get-instance-view --name $vmName --resource-group $ResourceGroupName --query instanceView.statuses --output table
    }
    
    "GetHostPoolStatus" {
        if (-not $HostPoolName) {
            Write-Error "HostPoolName is required for GetHostPoolStatus operation"
            exit 1
        }
        
        Write-Host "Getting host pool status: $HostPoolName" -ForegroundColor Blue
        
        # Host pool information
        Write-Host "`nHost Pool Information:" -ForegroundColor Cyan
        az desktopvirtualization hostpool show --name $HostPoolName --resource-group $ResourceGroupName --output table
        
        # Session hosts status
        Write-Host "`nSession Hosts Status:" -ForegroundColor Cyan
        az desktopvirtualization sessionhost list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output table
        
        # Active sessions
        Write-Host "`nActive Sessions:" -ForegroundColor Cyan
        az desktopvirtualization session list --host-pool-name $HostPoolName --resource-group $ResourceGroupName --output table
    }
    
    "UpdateHostPool" {
        if (-not $HostPoolName) {
            Write-Error "HostPoolName is required for UpdateHostPool operation"
            exit 1
        }
        
        Write-Host "Updating host pool settings: $HostPoolName" -ForegroundColor Blue
        
        # Example: Update load balancer type and max session limit
        az desktopvirtualization hostpool update `
            --name $HostPoolName `
            --resource-group $ResourceGroupName `
            --max-session-limit 20 `
            --load-balancer-type "BreadthFirst" `
            --output table
    }
    
    "ListApplications" {
        if (-not $ApplicationGroupName) {
            Write-Error "ApplicationGroupName is required for ListApplications operation"
            exit 1
        }
        
        Write-Host "Listing applications in application group: $ApplicationGroupName" -ForegroundColor Blue
        az desktopvirtualization application list --application-group-name $ApplicationGroupName --resource-group $ResourceGroupName --output table
    }
    
    "AssignUsers" {
        if (-not $ApplicationGroupName -or -not $UserPrincipalNames) {
            Write-Error "ApplicationGroupName and UserPrincipalNames are required for AssignUsers operation"
            exit 1
        }
        
        Write-Host "Assigning users to application group: $ApplicationGroupName" -ForegroundColor Blue
        
        foreach ($upn in $UserPrincipalNames) {
            Write-Host "Assigning user: $upn" -ForegroundColor Yellow
            
            # Get user object ID from Azure AD
            $userObjectId = az ad user show --id $upn --query id --output tsv
            
            if ($userObjectId) {
                # Assign user to application group
                az role assignment create `
                    --assignee $userObjectId `
                    --role "Desktop Virtualization User" `
                    --scope "/subscriptions/$((az account show --query id --output tsv))/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupName"
                
                Write-Host "Successfully assigned $upn to $ApplicationGroupName" -ForegroundColor Green
            }
            else {
                Write-Warning "Could not find user: $upn"
            }
        }
    }
}

Write-Host "Operation completed successfully!" -ForegroundColor Green
