param baseTime string = '${split(utcNow('u'), ' ')[0]} 07:00:00Z'
//11PM PST
var scheduleTime = dateTimeAdd(baseTime, 'P1D')
param jobGuid string = newGuid()

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: 'automation-wvd'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: 'runbook-wvd'
  location: resourceGroup().location
  parent: automationAccount
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/redanthrax/azureautomate/master/AVD/flushusers.ps1'
      contentHash: {
        algorithm: 'SHA256'
        value: 'F2F629025A145CFAAF556038A51DA9AF5AF991C5301850C41CB726A493A8D4F0'
      }
    }
  }
}

resource schedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  name: 'schedule-wvd'
  parent: automationAccount
  properties: {
    frequency: 'Day'
    startTime: scheduleTime
    timeZone: 'Pacific Standard Time'
    interval: 1
  }
}

resource job 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: guid('job-wvd-${uniqueString(jobGuid)}')
  parent: automationAccount
  properties: {
    runbook: {
      name: runbook.name
    }
    schedule: {
      name: schedule.name
    }
  }
}

param roleAssignmentName string = newGuid()

var role = {
  Owner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: role['Contributor']
    principalId: automationAccount.identity.principalId
  }
}
