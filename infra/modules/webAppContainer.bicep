@description('Web App name')
param name string

@description('Location')
param location string

@description('App Service plan resource id')
param serverFarmId string

@description('ACR login server (e.g., myregistry.azurecr.io)')
param acrLoginServer string

@description('Container image name')
param imageName string

@description('Container image tag')
param imageTag string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Log Analytics Workspace resource id')
param workspaceResourceId string

var linuxFxVersion = 'DOCKER|${acrLoginServer}/${imageName}:${imageTag}'

var rgTags = resourceGroup().tags ?? {}
var azdEnvName = resourceGroup().tags[?'azd-env-name'] ?? ''
var azdProjectName = resourceGroup().tags[?'azd-project-name'] ?? ''

var requiredTags = {
  CostControl: 'Ignore'
  SecurityControl: 'Ignore'
}

resource site 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  kind: 'app,linux,container'
  tags: union(rgTags, requiredTags, {
    'azd-service-name': 'web'
    'azd-env-name': azdEnvName
    'azd-project-name': azdProjectName
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarmId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diag'
  scope: site
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output name string = site.name
output id string = site.id
output defaultHostname string = site.properties.defaultHostName
output systemAssignedPrincipalId string = site.identity.principalId
