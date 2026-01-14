@description('Application Insights name')
param name string

@description('Location')
param location string

@description('Workspace resource id for workspace-based Application Insights')
param workspaceResourceId string

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource components 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
  }
}

output name string = components.name
output connectionString string = components.properties.ConnectionString
output instrumentationKey string = components.properties.InstrumentationKey
