@description('Log Analytics workspace name')
param name string

@description('Location')
param location string

@description('Retention in days (dev)')
param retentionInDays int = 30

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  properties: {
    retentionInDays: retentionInDays
    features: {
      searchVersion: 1
    }
  }
}

output name string = workspace.name
output workspaceResourceId string = workspace.id
