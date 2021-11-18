param guidValue string = newGuid()
param baseTime string = '${split(utcNow('u'), ' ')[0]} 07:00:00Z'
//11PM PST

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: 'automation-${uniqueString(guidValue)}'
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
  name: 'runbook-${uniqueString(guidValue)}'
  location: resourceGroup().location
  parent: automationAccount
  dependsOn: [
    automationAccount
  ]
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
      uri: 'github i guess'
      contentHash: {
        algorithm: 'SHA256'
        value: ''
      }
    }
  }
}

var scheduleTime = dateTimeAdd(baseTime, 'P1D')

resource schedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  name: 'schedule-${uniqueString(guidValue)}'
  parent: automationAccount
  dependsOn: [
    automationAccount
  ]
  properties: {
    frequency: 'Day'
    startTime: scheduleTime
    timeZone: 'Pacific Standard Time'
    interval: 1
  }
}

resource job 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: 'job-${uniqueString(guidValue)}'
  parent: automationAccount
  dependsOn: [
    automationAccount
    runbook
    schedule
  ]
  properties: {
    runbook: {
      name: runbook.name
    }
    schedule: {
      name: schedule.name
    }
  }
}
