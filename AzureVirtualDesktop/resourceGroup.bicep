targetScope = 'subscription'

param avdResourceGroup string
param loc string

resource avdResourceGroup_resource 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: avdResourceGroup
  location: loc
}
