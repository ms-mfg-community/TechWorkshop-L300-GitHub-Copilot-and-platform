using './main.bicep'

// azd-friendly parameter mapping.
// Values come from the current azd environment (.azure/<env>/.env) when present.

param location = readEnvironmentVariable('AZURE_LOCATION', 'westus3')
param environmentName = readEnvironmentVariable('environmentName', 'dev')
param namePrefix = readEnvironmentVariable('namePrefix', 'zava')

// These may be set by azd post-deploy hook (infra/deploy-container.ps1)
param imageName = readEnvironmentVariable('imageName', 'zavastorefront')
param imageTag = readEnvironmentVariable('imageTag', 'dev')

// Enable/disable Foundry resources
param enableAi = toLower(readEnvironmentVariable('enableAi', 'false')) == 'true'
