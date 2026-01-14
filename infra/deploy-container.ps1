param(
  [string]$ImageRepo = 'zavastorefront',
  [string]$ImageTag = '',
  [string]$StableTag = 'dev'
)

$ErrorActionPreference = 'Stop'

function Require-EnvVar([string]$name) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Missing required environment variable '$name'. Run 'azd provision' first so outputs are available (e.g., webAppNameOut, acrNameOut)."
  }
  return $value
}

$subscriptionId = Require-EnvVar 'AZURE_SUBSCRIPTION_ID'
$resourceGroup = Require-EnvVar 'AZURE_RESOURCE_GROUP'
$acrName = Require-EnvVar 'acrNameOut'
$acrLoginServer = Require-EnvVar 'acrLoginServer'
$webAppName = Require-EnvVar 'webAppNameOut'

if ([string]::IsNullOrWhiteSpace($ImageTag)) {
  try {
    $ImageTag = (git rev-parse --short HEAD).Trim()
  } catch {
    $ImageTag = (Get-Date -Format 'yyyyMMddHHmmss')
  }
}

Write-Host "Using subscription: $subscriptionId"
Write-Host "Using resource group: $resourceGroup"
Write-Host "Using ACR: $acrName ($acrLoginServer)"
Write-Host "Using Web App: $webAppName"
Write-Host "Building image: ${ImageRepo}:${ImageTag}"
Write-Host "Also tagging stable tag: ${ImageRepo}:${StableTag}"

# Ensure Azure CLI context is set (azd typically authenticates already).
az account set --subscription $subscriptionId | Out-Null

# Cloud build/push (no local Docker required)
az acr build `
  -r $acrName `
  -t "${ImageRepo}:${ImageTag}" `
  -t "${ImageRepo}:${StableTag}" `
  -f "./src/Dockerfile" `
  "./src" | Out-Host

# Persist the latest tag into the azd environment so future `azd provision`
# uses an image tag that actually exists.
try {
  azd env set imageName $ImageRepo | Out-Null
  azd env set imageTag $ImageTag | Out-Null
  Write-Host "Updated azd env: imageName=${ImageRepo}, imageTag=${ImageTag}"
} catch {
  Write-Warning "Could not update azd environment values (imageName/imageTag). You can set them manually with 'azd env set'."
}

# Update the Web App to the new image.
$fullImage = "$acrLoginServer/${ImageRepo}:${ImageTag}"

az webapp config container set `
  --resource-group $resourceGroup `
  --name $webAppName `
  --docker-custom-image-name $fullImage `
  --docker-registry-server-url "https://$acrLoginServer" | Out-Host

# Ensure app listens on the same port as the Dockerfile.
az webapp config appsettings set `
  --resource-group $resourceGroup `
  --name $webAppName `
  --settings WEBSITES_PORT=8080 | Out-Host

az webapp restart --resource-group $resourceGroup --name $webAppName | Out-Host

Write-Host "Container deployment completed: https://$($env:webAppDefaultHostname)"