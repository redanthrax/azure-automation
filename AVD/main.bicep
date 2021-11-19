targetScope = 'subscription'

@description('The resource group must match the location specified.')
param resourceGroupName string

module automationAccount 'automationAccount.bicep' = {
  name: 'automationAccount'
  scope: resourceGroup(resourceGroupName)
}

var roleAssignmentName = guid(resourceGroupName)

var role = {
  Owner: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: roleAssignmentName
  dependsOn: [
    automationAccount
  ]
  scope: subscription()
  properties: {
    roleDefinitionId: role['Contributor']
    principalId: automationAccount.outputs.automationAccountPid
  }
}
