# GitHub Actions quickstart: build + deploy container to App Service

This repo provisions a **Linux Web App for Containers** + **Azure Container Registry (ACR)** from the Bicep in `infra/`.
The workflow in `.github/workflows/deploy-appservice-container.yml` builds the container from `src/Dockerfile` (via `az acr build`) and deploys it to the Web App.

Deploy behavior:
- Pull requests into `main`: build only (no deploy)
- Pushes to `main`: build, then deploy **only if `src/**` changed**
- Manual runs (`workflow_dispatch`): build + deploy

## 1) Configure GitHub Secrets (Azure login)

Create an Azure AD app registration and configure **GitHub OIDC** (recommended). Then set these repository secrets:

- `AZURE_CLIENT_ID` — the app registration (service principal) client ID
- `AZURE_TENANT_ID` — your Entra tenant ID
- `AZURE_SUBSCRIPTION_ID` — subscription containing the resource group

Notes:
- The workflow uses `azure/login@v2` with OIDC, so no client secret is required.
- The service principal needs permissions to:
  - build/push to ACR (e.g., `AcrPush` on the registry)
  - update the Web App container config (e.g., `Contributor` on the web app or resource group)

## 2) Configure GitHub Variables (deployment targets)

Set these repository **variables** (Settings → Secrets and variables → Actions → Variables):

- `ACR_NAME` — ACR resource name (Bicep output `acrNameOut`)
- `WEBAPP_NAME` — Web App name (Bicep output `webAppNameOut`)
- `AZURE_RESOURCE_GROUP` — resource group name where infra was deployed

## 3) Run the workflow

- Run manually: Actions → “Build and deploy container to App Service” → Run workflow
- Or push to `main` (default trigger)

The workflow tags images as:
- `${GITHUB_SHA::7}` (deployed)
- `dev` (stable tag)
