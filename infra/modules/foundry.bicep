@description('Name for the AI/Foundry hub/workspace (scaffold)')
param name string

@description('Location')
param location string

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

@description('SKU name for the Foundry resource (commonly S0)')
param skuName string = 'S0'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  kind: 'AIServices'
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Keep minimal; additional configuration (networking, custom subdomain, projects) can be added later.
  }
}

output name string = foundry.name
output id string = foundry.id
