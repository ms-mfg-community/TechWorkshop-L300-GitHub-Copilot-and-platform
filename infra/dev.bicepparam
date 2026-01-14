using './main.bicep'

param location = 'westus3'
param environmentName = 'dev'
param namePrefix = 'zava'
param acrSku = 'Basic'
param appServiceSkuName = 'B1'
param imageName = 'zavastorefront'
param imageTag = 'dev'
param enableAi = false
