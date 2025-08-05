@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Host pool name for registration')
param hostPoolName string

@description('VM name prefix for session hosts')
param vmNamePrefix string

@description('Current UTC time')
param utcValue string = utcNow()

// Get the host pool
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' existing = {
  name: hostPoolName
}

// Deployment script to get registration token and install AVD agent
resource getRegistrationToken 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${vmNamePrefix}-get-reg-token'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '9.7'
    timeout: 'PT30M'
    arguments: '-HostPoolName "${hostPoolName}" -ResourceGroupName "${resourceGroup().name}" -VMName "${vmNamePrefix}-0"'
    scriptContent: '''
      param(
          [string]$HostPoolName,
          [string]$ResourceGroupName,
          [string]$VMName
      )
      
      Write-Output "Getting registration token for host pool: $HostPoolName"
      
      try {
          # Get registration token
          $token = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours(2)
          
          Write-Output "Registration token obtained successfully"
          
          # Install AVD agent on the VM using custom script extension
          $agentScript = @"
try {
    Write-Host 'Installing AVD Agent...'
    `$agentUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
    `$bootUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
    
    Invoke-WebRequest -Uri `$agentUrl -OutFile 'C:\agent.msi'
    Start-Process msiexec -ArgumentList '/i C:\agent.msi /quiet REGISTRATIONTOKEN=$($token.Token)' -Wait
    
    Invoke-WebRequest -Uri `$bootUrl -OutFile 'C:\boot.msi'
    Start-Process msiexec -ArgumentList '/i C:\boot.msi /quiet' -Wait
    
    Write-Host 'AVD Agent installed successfully'
} catch {
    Write-Error `$_.Exception.Message
    exit 1
}
"@

          # Apply the script to the VM
          $scriptSettings = @{
              'commandToExecute' = "powershell -ExecutionPolicy Unrestricted -Command `"$agentScript`""
          }
          
          Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AVDHostRegistration" -FileUri @() -Run "powershell -ExecutionPolicy Unrestricted -Command `"$agentScript`"" -Location (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName).Location
          
          Write-Output "AVD agent installation completed"
          
          $DeploymentScriptOutputs = @{}
          $DeploymentScriptOutputs['registrationToken'] = $token.Token
          $DeploymentScriptOutputs['message'] = "AVD agent installed successfully"
      }
      catch {
          Write-Error "Failed to install AVD agent: $($_.Exception.Message)"
          throw
      }
    '''
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// Role assignment for the deployment script managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, getRegistrationToken.name, 'Desktop Virtualization Power On Off Contributor')
  scope: hostPool
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '489581de-a3bd-480d-9518-53dea7416b33')
    principalId: getRegistrationToken.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Additional role assignment for VM management
resource vmRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, getRegistrationToken.name, 'Virtual Machine Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
    principalId: getRegistrationToken.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output registrationToken string = getRegistrationToken.properties.outputs.registrationToken
output message string = getRegistrationToken.properties.outputs.message
