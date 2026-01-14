@description('Azure Container Registry name (must be globally unique, 5-50 chars, alphanumeric)')
param name string

@description('Location')
param location string

@description('SKU name')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: union(resourceGroup().tags ?? {}, requiredTags)
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output name string = registry.name
output loginServer string = registry.properties.loginServer
output registryId string = registry.id
