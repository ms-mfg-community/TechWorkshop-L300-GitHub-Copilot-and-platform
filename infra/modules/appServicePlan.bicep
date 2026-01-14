@description('App Service Plan name')
param name string

@description('Location')
param location string

@description('SKU name (e.g., B1)')
param skuName string = 'B1'

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource plan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: name
  location: location
  kind: 'linux'
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  sku: {
    name: skuName
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

output name string = plan.name
output serverFarmId string = plan.id
