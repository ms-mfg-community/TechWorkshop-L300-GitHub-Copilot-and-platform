@description('Name for the AI/Foundry hub/workspace (scaffold)')
param name string

@description('Location')
param location string

@description('Optional resource id of an existing Application Insights (for ML workspace diagnostics)')
param applicationInsightsId string = ''

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: name
  location: location
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: name
    description: 'Dev AI/Foundry workspace scaffold'
    applicationInsights: empty(applicationInsightsId) ? null : applicationInsightsId
    allowPublicAccessWhenBehindVnet: false
    publicNetworkAccess: 'Enabled'
  }
}

output name string = workspace.name
output id string = workspace.id
