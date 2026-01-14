# ZavaStorefront — Azure Infrastructure (scaffold)

This folder contains **Bicep IaC scaffolding** for the workshop issue “Provision Azure infrastructure for ZavaStorefront (dev) with RBAC container deployment, Application Insights, and Foundry”.

No Azure provisioning has been executed by this repo change.

## Layout

- `main.bicep`: orchestrates all modules
- `modules/`
  - `acr.bicep`: Azure Container Registry (admin user disabled)
  - `appServicePlan.bicep`: Linux App Service Plan
  - `webAppContainer.bicep`: Linux Web App for Containers + diagnostic settings
  - `roleAssignment-acrPull.bicep`: grants `AcrPull` to the Web App’s system identity
  - `logAnalytics.bicep`: Log Analytics workspace
  - `appInsights.bicep`: workspace-based Application Insights
  - `foundry.bicep`: **scaffold** Azure AI / Foundry workspace (enable with `enableAi=true`)

## Dockerfile

- Dockerfile: `src/Dockerfile`
- Build context: `src/`

## How you will run this later (commands only)

### 1) Provision (later)

Using `azd` (recommended for workshop):
- `azd init`
- `azd provision`

Or using Azure CLI:
- `az deployment group create -g <rg-name> -f infra/main.bicep -p infra/dev.bicepparam`

### 2) Build/push container image (later)

No local Docker required:
- `az acr build -r <acrName> -t zavastorefront:<tag> -f src/Dockerfile ./src`

Optional local Docker (since you have it installed):
- `az acr login -n <acrName>`
- `docker build -t <loginServer>/zavastorefront:<tag> -f src/Dockerfile ./src`
- `docker push <loginServer>/zavastorefront:<tag>`

### 3) Update the Web App to the new image tag (later)

- `az webapp config container set -g <rg> -n <webapp> --docker-custom-image-name <loginServer>/zavastorefront:<tag> --docker-registry-server-url https://<loginServer>`

## Notes / caveats

- `enableAi` is `false` by default because model availability + exact “Foundry” resource composition can vary by region and may need validation in `westus3`.
- App-level telemetry in Application Insights may require adding the Application Insights SDK (or OpenTelemetry) to the app code; the infrastructure provisions App Insights and routes platform logs to Log Analytics.

## azd up: container deployment wiring

This repo uses a command-level `postdeploy` hook in `azure.yaml` that runs `infra/deploy-container.ps1`.

That hook:
- Builds/pushes the image using `az acr build` (cloud build)
- Updates the App Service container image to the new tag
- Sets `WEBSITES_PORT=8080` and restarts the app
