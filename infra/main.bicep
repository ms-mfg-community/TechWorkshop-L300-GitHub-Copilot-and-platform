@description('Deployment location for all resources')
param location string = 'westus3'

@description('Environment name (e.g., dev)')
param environmentName string = 'dev'

@description('Short prefix for resource names (letters/numbers/hyphens). Used as a seed; some resources require global uniqueness.')
param namePrefix string = 'zava'

@description('ACR SKU for dev')
@allowed([
  'Basic'
  'Standard'
])
param acrSku string = 'Basic'

@description('App Service Plan SKU (e.g., B1)')
param appServiceSkuName string = 'B1'

@description('Container image name (repository) in ACR')
param imageName string = 'zavastorefront'

@description('Container image tag')
param imageTag string = 'dev'

@description('Enable Azure AI/Foundry-related resources (scaffold only; may need adjustments based on region/model availability)')
param enableAi bool = false

var unique = toLower(uniqueString(resourceGroup().id, namePrefix, environmentName))
var sanitizedPrefix = toLower(replace(replace(namePrefix, '-', ''), '_', ''))

// ACR name: 5-50 chars, alphanumeric, must start with a letter
var acrName = take('${sanitizedPrefix}${environmentName}${unique}', 50)

// App Service names allow hyphens
var planName = 'asp-${namePrefix}-${environmentName}-${unique}'
var webAppName = 'app-${namePrefix}-${environmentName}-${unique}'
var laName = 'law-${namePrefix}-${environmentName}-${unique}'
var aiName = 'appi-${namePrefix}-${environmentName}-${unique}'

module logAnalytics './modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: laName
    location: location
  }
}

module appInsights './modules/appInsights.bicep' = {
  name: 'appInsights'
  params: {
    name: aiName
    location: location
    workspaceResourceId: logAnalytics.outputs.workspaceResourceId
  }
}

module acr './modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: acrName
    location: location
    sku: acrSku
  }
}

module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlan'
  params: {
    name: planName
    location: location
    skuName: appServiceSkuName
  }
}

module webApp './modules/webAppContainer.bicep' = {
  name: 'webApp'
  params: {
    name: webAppName
    location: location
    serverFarmId: appServicePlan.outputs.serverFarmId
    acrLoginServer: acr.outputs.loginServer
    imageName: imageName
    imageTag: imageTag
    appInsightsConnectionString: appInsights.outputs.connectionString
    workspaceResourceId: logAnalytics.outputs.workspaceResourceId
  }
}

module acrPull './modules/roleAssignment-acrPull.bicep' = {
  name: 'acrPull'
  params: {
    acrName: acr.outputs.name
    principalId: webApp.outputs.systemAssignedPrincipalId
  }
}

module foundry './modules/foundry.bicep' = if (enableAi) {
  name: 'foundry'
  params: {
    name: 'ai-${namePrefix}-${environmentName}-${unique}'
    location: location
  }
}

output resourceGroupName string = resourceGroup().name
output acrNameOut string = acr.outputs.name
output acrLoginServer string = acr.outputs.loginServer
output webAppNameOut string = webApp.outputs.name
output webAppDefaultHostname string = webApp.outputs.defaultHostname
output appInsightsName string = appInsights.outputs.name
