# GitHub Actions Documentation

## Overview

This repository uses GitHub Actions for automated CI/CD workflows to deploy containerized applications to Azure App Service and static documentation to GitHub Pages. Our automation ensures reliable, secure deployments with minimal manual intervention.

**Repository**: TechWorkshop-L300-GitHub-Copilot-and-platform

### Quick Summary

- **Total Workflows**: 2 active workflows
- **Deployment Targets**: 
  - Azure App Service (Web App for Containers)
  - GitHub Pages (Jekyll static site)
- **Security Features**: OIDC authentication, explicit permissions, environment-based deployments
- **Supported Environments**: dev, staging, production (Azure), github-pages (static site)

### Workflow Summary

| Workflow Name | File | Primary Trigger | Purpose |
|---------------|------|-----------------|---------|
| Build and deploy container to App Service | `deploy-appservice-container.yml` | Push to main, Manual | Build Docker container in ACR and deploy to Azure App Service |
| Deploy Jekyll with GitHub Pages | `jekyll-gh-pages.yml` | Push to main, Manual | Build Jekyll site and deploy to GitHub Pages |

---

## Workflows

### 1. Build and Deploy Container to App Service

**File**: `.github/workflows/deploy-appservice-container.yml`

**Purpose**: Builds a Docker container image in Azure Container Registry (ACR) and deploys it to Azure App Service (Web App for Containers). This is the main CI/CD pipeline for the containerized web application.

#### When This Workflow Runs

**Automatic Triggers**:
- **Push to main branch** - Runs automatically when changes are pushed to `main` that affect:
  - Source code: `src/**`
  - Docker configuration: `**/Dockerfile`, `.dockerignore`
  - Compose files: `docker-compose*.yml`
  - Deployment scripts: `infra/deploy-container.ps1`

- **Pull Requests to main** - Validates builds (same path filters as push)

**Manual Trigger**:
- Can be run manually from the Actions tab with environment selection:
  1. Go to **Actions** tab
  2. Select **"Build and deploy container to App Service"**
  3. Click **"Run workflow"**
  4. Choose environment: `dev`, `staging`, or `production`
  5. Click **"Run workflow"**

#### Required Configuration

##### Secrets (Repository or Environment)
These must be configured in Settings → Secrets and variables → Actions:

| Secret Name | Description | Example Value | Required For |
|-------------|-------------|---------------|--------------|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID for OIDC | `12345678-1234-1234-1234-123456789012` | Azure authentication |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `87654321-4321-4321-4321-210987654321` | Azure authentication |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdef12-3456-7890-abcd-ef1234567890` | Azure authentication |

##### Variables (Repository or Environment)
These must be configured in Settings → Secrets and variables → Actions → Variables tab:

| Variable Name | Description | Example Value | Required For |
|---------------|-------------|---------------|--------------|
| `ACR_NAME` | Azure Container Registry name | `myregistry` | Building and pulling images |
| `AZURE_RESOURCE_GROUP` | Azure resource group name | `rg-workshop-prod` | Deployment target |
| `WEBAPP_NAME` | Azure Web App name | `webapp-workshop-prod` | Deployment target |

> **💡 Tip**: Use environment-specific values by configuring these variables per GitHub Environment (dev, staging, production) instead of repository-level.

#### What This Workflow Does

**Step-by-Step Breakdown**:

1. **Checkout Code** (`actions/checkout@v4`)
   - Clones the repository with full git history
   - Enables version tagging and changelog generation

2. **Azure Login** (`azure/login@v2`)
   - Authenticates to Azure using OpenID Connect (OIDC)
   - No long-lived credentials stored - tokens generated per run
   - Provides access to Azure CLI commands

3. **Resolve Image Tags**
   - Creates commit-based tag: First 7 characters of commit SHA (e.g., `a1b2c3d`)
   - Creates environment tag: `dev`, `staging`, or `production`
   - Both tags are applied to the same image for traceability

4. **Build Container in ACR**
   - Uses Azure Container Registry cloud build (no local Docker required)
   - Builds from `./src/Dockerfile`
   - Tags image with both commit SHA and environment label
   - Example: `zavastorefront:a1b2c3d` and `zavastorefront:dev`

5. **Deploy to App Service**
   - Updates Web App container configuration to use new image
   - Configures container port mapping (8080)
   - Restarts the app to apply changes
   - Validates all required variables before deployment

#### Complete Workflow Code

```yaml
name: Build and deploy container to App Service

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - production
  push:
    branches: [ main ]
    paths:
      - 'src/**'
      - 'src/Dockerfile'
      - '**/Dockerfile'
      - '.dockerignore'
      - '**/.dockerignore'
      - 'docker-compose*.yml'
      - '**/docker-compose*.yml'
      - 'infra/deploy-container.ps1'
  pull_request:
    branches: [ main ]
    paths:
      - 'src/**'
      - 'src/Dockerfile'
      - '**/Dockerfile'
      - '.dockerignore'
      - '**/.dockerignore'
      - 'docker-compose*.yml'
      - '**/docker-compose*.yml'
      - 'infra/deploy-container.ps1'

permissions:
  id-token: write  # Required for OIDC authentication
  contents: read   # Read repository contents

env:
  IMAGE_REPO: zavastorefront

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Resolve image tag
        id: vars
        shell: bash
        run: |
          echo "IMAGE_TAG=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
          echo "STABLE_TAG=${{ inputs.environment || 'dev' }}" >> "$GITHUB_OUTPUT"

      - name: Build in ACR (cloud build, no local Docker)
        shell: bash
        env:
          ACR_NAME: ${{ vars.ACR_NAME }}
        run: |
          test -n "$ACR_NAME" || (echo "Missing vars.ACR_NAME" && exit 1)

          az acr build \
            -r "$ACR_NAME" \
            -t "${IMAGE_REPO}:${{ steps.vars.outputs.IMAGE_TAG }}" \
            -t "${IMAGE_REPO}:${{ steps.vars.outputs.STABLE_TAG }}" \
            -f "./src/Dockerfile" \
            "./src"

      - name: Deploy to App Service (Web App for Containers)
        shell: bash
        env:
          RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
          WEBAPP_NAME: ${{ vars.WEBAPP_NAME }}
          ACR_NAME: ${{ vars.ACR_NAME }}
        run: |
          test -n "$RESOURCE_GROUP" || (echo "Missing vars.AZURE_RESOURCE_GROUP" && exit 1)
          test -n "$WEBAPP_NAME" || (echo "Missing vars.WEBAPP_NAME" && exit 1)
          test -n "$ACR_NAME" || (echo "Missing vars.ACR_NAME" && exit 1)

          ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
          FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_REPO}:${{ steps.vars.outputs.IMAGE_TAG }}"

          az webapp config container set \
            --resource-group "$RESOURCE_GROUP" \
            --name "$WEBAPP_NAME" \
            --docker-custom-image-name "$FULL_IMAGE" \
            --docker-registry-server-url "https://${ACR_LOGIN_SERVER}"

          # Keep app settings consistent with the Dockerfile (listening on 8080)
          az webapp config appsettings set \
            --resource-group "$RESOURCE_GROUP" \
            --name "$WEBAPP_NAME" \
            --settings WEBSITES_PORT=8080

          az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
```

#### Security Features

**✅ OpenID Connect (OIDC) Authentication**
- Uses federated identity for Azure authentication
- No long-lived credentials stored in GitHub
- Short-lived tokens generated per workflow run
- Eliminates credential rotation requirements

**✅ Minimal Permissions**
```yaml
permissions:
  id-token: write  # Required for OIDC token generation
  contents: read   # Read repository contents only
```

**✅ Environment-Based Deployment**
- Supports GitHub Environments (dev, staging, production)
- Enables environment-specific protection rules
- Can require manual approvals before deployment
- Environment-specific secrets and variables

**✅ Variable Validation**
- Validates all required variables before execution
- Fails fast with clear error messages
- Prevents partial deployments

#### Environment Setup

To configure environments for this workflow:

1. **Go to Settings → Environments**
2. **Create environments**: `dev`, `staging`, `production`
3. **For each environment, configure**:
   - **Variables**: `ACR_NAME`, `AZURE_RESOURCE_GROUP`, `WEBAPP_NAME`
   - **Protection rules** (optional):
     - Required reviewers for production
     - Wait timer before deployment
     - Allowed branches (e.g., only main)

**Example Environment Configuration**:

| Environment | ACR_NAME | AZURE_RESOURCE_GROUP | WEBAPP_NAME |
|-------------|----------|---------------------|-------------|
| dev | `workshopacr` | `rg-workshop-dev` | `webapp-workshop-dev` |
| staging | `workshopacr` | `rg-workshop-staging` | `webapp-workshop-staging` |
| production | `workshopacr` | `rg-workshop-prod` | `webapp-workshop-prod` |

---

### 2. Deploy Jekyll with GitHub Pages

**File**: `.github/workflows/jekyll-gh-pages.yml`

**Purpose**: Builds a Jekyll static site and deploys it to GitHub Pages. This workflow handles documentation and website deployment automatically.

#### When This Workflow Runs

**Automatic Trigger**:
- **Push to main branch** - Runs on any commit to `main` (no path filters)

**Manual Trigger**:
- Can be run manually from the Actions tab:
  1. Go to **Actions** tab
  2. Select **"Deploy Jekyll with GitHub Pages dependencies preinstalled"**
  3. Click **"Run workflow"**
  4. Click **"Run workflow"** (no inputs required)

#### Required Configuration

##### GitHub Pages Setup
1. Go to **Settings → Pages**
2. Set **Source** to: **GitHub Actions** (not "Deploy from a branch")
3. No secrets or variables required (uses automatic `GITHUB_TOKEN`)

#### What This Workflow Does

This workflow consists of two jobs that run sequentially:

**Job 1: Build** (Compiles Jekyll site)
1. **Checkout Code** - Clones the repository
2. **Setup Ruby** - Installs Ruby 3.1 and caches bundler dependencies
3. **Setup Pages** - Configures GitHub Pages settings and base path
4. **Build with Jekyll** - Compiles site to `./_site` directory
5. **Upload Artifact** - Saves built site for deployment job

**Job 2: Deploy** (Deploys to GitHub Pages)
1. **Deploy to GitHub Pages** - Publishes the built site
2. **Outputs URL** - Provides the live site URL

#### Complete Workflow Code

```yaml
name: Deploy Jekyll with GitHub Pages dependencies preinstalled

on:
  # Runs on pushes targeting the default branch
  push:
    branches: ["main"]

  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:

# Sets permissions of the GITHUB_TOKEN to allow deployment to GitHub Pages
permissions:
  contents: read
  pages: write
  id-token: write

# Allow only one concurrent deployment to GitHub Pages
concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  # Build job
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1' # Not needed with a .ruby-version file
          bundler-cache: true # runs 'bundle install' and caches installed gems automatically
          cache-version: 0 # Increment this number if you need to re-download cached gems
      - name: Setup Pages
        id: pages
        uses: actions/configure-pages@v4
      - name: Build with Jekyll
        # Outputs to the './_site' directory by default
        run: bundle exec jekyll build --baseurl "${{ steps.pages.outputs.base_path }}"
        env:
          JEKYLL_ENV: production
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3

  # Deployment job
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

#### Security Features

**✅ Explicit Permissions**
```yaml
permissions:
  contents: read    # Read repository contents
  pages: write      # Deploy to GitHub Pages
  id-token: write   # Required for Pages deployment attestation
```

**✅ Concurrency Control**
```yaml
concurrency:
  group: "pages"
  cancel-in-progress: true
```
- Prevents multiple simultaneous deployments
- Cancels in-progress deployments when new one starts
- Ensures consistent deployment state

**✅ Dependency Caching**
- Ruby gems are cached automatically
- Speeds up subsequent builds
- Cache can be invalidated by incrementing `cache-version`

---

## CI Trigger Reference

### Supported Trigger Types in This Repository

#### Push Events

Trigger workflows when commits are pushed to specific branches.

**Example from Container Workflow**:
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'src/**'
      - '**/Dockerfile'
      - '.dockerignore'
```

**Use Cases**:
- Continuous integration on main branch
- Automated deployments
- Build validation

**Path Filters**: Include or exclude files to optimize workflow runs
- `paths:` - Run only when these files change
- `paths-ignore:` - Run unless only these files change

#### Pull Request Events

Trigger workflows on pull request activity.

**Example from Container Workflow**:
```yaml
on:
  pull_request:
    branches: [ main ]
    paths:
      - 'src/**'
      - '**/Dockerfile'
```

**Use Cases**:
- Code review checks
- Test validation before merge
- Build verification

**Available PR Types**: `opened`, `synchronize`, `reopened`, `closed`, etc.

#### Manual Triggers (workflow_dispatch)

Allow workflows to be triggered manually from the Actions tab.

**Simple Manual Trigger** (Jekyll workflow):
```yaml
on:
  workflow_dispatch:
```

**Manual Trigger with Inputs** (Container workflow):
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - production
```

**Use Cases**:
- On-demand deployments
- Testing workflow changes
- Emergency fixes
- Production releases requiring manual approval

### Other GitHub Actions Triggers

While not currently used in this repository, GitHub Actions supports many other trigger types:

- **schedule** - Run on a schedule (cron syntax)
- **workflow_call** - Make workflows reusable
- **release** - Trigger on release creation
- **issues** / **issue_comment** - Automate issue management
- **repository_dispatch** - Trigger via API/webhooks
- **workflow_run** - Chain workflows together

---

## Workflow Syntax Guide

### Basic Workflow Structure

```yaml
name: My Workflow Name
on: [push, pull_request]

permissions:
  contents: read

jobs:
  job-id:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run commands
        run: echo "Hello World"
```

### Jobs Configuration

#### Job Dependencies

Use `needs:` to create job dependencies (example from Jekyll workflow):

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build site
        run: bundle exec jekyll build
  
  deploy:
    runs-on: ubuntu-latest
    needs: build  # Wait for build job to complete
    steps:
      - name: Deploy
        run: echo "Deploying..."
```

#### Environment Assignment

Assign jobs to GitHub Environments (from container workflow):

```yaml
jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}  # Dynamic environment
```

#### Conditional Execution

Use `if:` conditions to control job execution:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'  # Only on main branch
    runs-on: ubuntu-latest
```

### Steps Configuration

#### Using Actions

```yaml
- name: Checkout code
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

#### Running Commands

```yaml
- name: Run build
  run: npm run build
  working-directory: ./frontend
  env:
    NODE_ENV: production
```

#### Multi-line Scripts (from container workflow)

```yaml
- name: Build in ACR
  shell: bash
  env:
    ACR_NAME: ${{ vars.ACR_NAME }}
  run: |
    test -n "$ACR_NAME" || (echo "Missing vars.ACR_NAME" && exit 1)
    
    az acr build \
      -r "$ACR_NAME" \
      -t "${IMAGE_REPO}:${{ steps.vars.outputs.IMAGE_TAG }}" \
      -f "./src/Dockerfile" \
      "./src"
```

#### Step Outputs

Create outputs for use in later steps (from container workflow):

```yaml
- name: Resolve image tag
  id: vars
  run: |
    echo "IMAGE_TAG=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
    echo "STABLE_TAG=production" >> "$GITHUB_OUTPUT"

- name: Use the output
  run: |
    echo "Tag is ${{ steps.vars.outputs.IMAGE_TAG }}"
```

### Context Variables

Common context variables used in this repository:

| Variable | Description | Example |
|----------|-------------|---------|
| `${{ github.sha }}` | Commit SHA | `a1b2c3d4e5f6g7h8i9j0...` |
| `${{ github.ref }}` | Git ref | `refs/heads/main` |
| `${{ github.actor }}` | User who triggered | `username` |
| `${{ secrets.SECRET_NAME }}` | Repository secret | `***` |
| `${{ vars.VAR_NAME }}` | Repository/environment variable | `myvalue` |
| `${{ inputs.input_name }}` | Workflow dispatch input | `dev` |
| `${{ steps.step_id.outputs.output_name }}` | Step output | `value` |

---

## Workflow Commands

### Logging and Output

#### Set Step Outputs (Recommended)

Used in the container workflow:

```yaml
- name: Set outputs
  run: |
    echo "version=1.0.0" >> "$GITHUB_OUTPUT"
    echo "tag=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
```

#### Job Summaries

Add markdown summaries visible in the Actions UI:

```yaml
- name: Deployment Summary
  run: |
    echo "## Deployment Complete! 🚀" >> "$GITHUB_STEP_SUMMARY"
    echo "" >> "$GITHUB_STEP_SUMMARY"
    echo "- **Environment**: production" >> "$GITHUB_STEP_SUMMARY"
    echo "- **Image Tag**: ${{ steps.vars.outputs.IMAGE_TAG }}" >> "$GITHUB_STEP_SUMMARY"
    echo "- **URL**: https://myapp.azurewebsites.net" >> "$GITHUB_STEP_SUMMARY"
```

#### Workflow Commands

```yaml
- name: Status messages
  run: |
    echo "::notice::Build completed successfully"
    echo "::warning::Using development configuration"
    echo "::error::Deployment failed"
```

### Grouping Logs

Collapse log output into expandable groups:

```yaml
- name: Install dependencies
  run: |
    echo "::group::Installing packages"
    npm install
    echo "::endgroup::"
    
    echo "::group::Running build"
    npm run build
    echo "::endgroup::"
```

### Debugging

Enable debug logging by setting repository secrets:
- `ACTIONS_STEP_DEBUG` = `true` (detailed step logs)
- `ACTIONS_RUNNER_DEBUG` = `true` (runner diagnostic logs)

---

## Security Best Practices

### Secrets Management

**✅ Current Practice in This Repository**:
- Secrets stored in GitHub Secrets (never in code)
- OIDC used for Azure (no long-lived credentials)
- Explicit permission scopes

**How to Add Secrets**:
1. Go to **Settings → Secrets and variables → Actions**
2. Click **"New repository secret"** or **"New environment secret"**
3. Enter name and value
4. Click **"Add secret"**

**Best Practices**:
- Use environment-specific secrets when possible
- Rotate secrets regularly (or use OIDC)
- Never log secrets (`echo "${{ secrets.MY_SECRET }}"` will be masked automatically)
- Use the minimum required scope

### Token Permissions

**✅ Both workflows use explicit minimal permissions**:

**Container Workflow**:
```yaml
permissions:
  id-token: write  # OIDC authentication
  contents: read   # Read code
```

**Jekyll Workflow**:
```yaml
permissions:
  contents: read   # Read code
  pages: write     # Deploy to Pages
  id-token: write  # Pages attestation
```

**Available Permission Scopes**:
- `actions: read/write` - Workflow access
- `checks: read/write` - Check runs
- `contents: read/write` - Repository contents
- `deployments: read/write` - Deployments
- `id-token: write` - OIDC tokens
- `issues: read/write` - Issues
- `packages: read/write` - GitHub Packages
- `pages: write` - GitHub Pages
- `pull-requests: read/write` - Pull requests
- `security-events: write` - Security alerts

### OpenID Connect (OIDC)

**✅ Azure Container Workflow Uses OIDC**

OIDC eliminates long-lived credentials by generating short-lived tokens.

**Current Azure OIDC Configuration**:
```yaml
- name: Azure login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**Required Azure Setup**:
1. Create Azure AD App Registration
2. Configure Federated Credentials in Azure AD:
   - **Entity type**: GitHub Actions
   - **Organization**: Your GitHub org
   - **Repository**: Your repo name
   - **Entity**: environment (dev/staging/production)
3. Assign Azure RBAC roles to the App Registration
4. Add secrets to GitHub (client ID, tenant ID, subscription ID)

**Benefits**:
- ✅ No stored credentials
- ✅ Short-lived tokens (minutes)
- ✅ Automatic token rotation
- ✅ Centralized access control in Azure

### Action Pinning

**⚠️ Current State**: Actions are pinned to major version tags (`@v4`, `@v2`)

**Security Risk**: Version tags can be moved by action maintainers, potentially introducing malicious code.

**Recommendation**: Pin to immutable commit SHAs

**Example**:
```yaml
# Current (less secure)
- uses: actions/checkout@v4
- uses: azure/login@v2

# Recommended (more secure)
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: azure/login@92a5484dfca0f8b0a63a5c8edc2e5d92d8c1e6b5  # v2.0.0
```

**How to Find Commit SHAs**:
1. Go to the action's GitHub repository
2. Find the release tag you want
3. Copy the commit SHA from that tag
4. Add a comment with the version for reference

**Automation**: Use Dependabot to keep pinned actions updated:

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## Deployment Targets

### Azure App Service (Web App for Containers)

**Workflow**: `deploy-appservice-container.yml`

**Architecture**:
- **Container Registry**: Azure Container Registry (ACR)
- **Compute Platform**: Azure App Service (PaaS)
- **Container Runtime**: Linux containers
- **Image Repository**: `zavastorefront`

**Deployment Flow**:
1. Build container image in ACR using cloud build (`az acr build`)
2. Tag with commit SHA and environment label
3. Update Web App configuration to point to new image
4. Configure container port (8080)
5. Restart Web App to apply changes

**Environment Strategy**:
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     dev     │ -> │   staging   │ -> │ production  │
└─────────────┘    └─────────────┘    └─────────────┘
   Auto deploy      Auto deploy       Manual trigger
   from main        from main         or auto from main
```

**Current Configuration**:
- **Image Naming**: `{ACR_NAME}.azurecr.io/zavastorefront:{TAG}`
- **Port Mapping**: Container port 8080 → `WEBSITES_PORT=8080`
- **Authentication**: ACR integration via managed identity or OIDC

**Accessing Your Deployment**:
- Dev: `https://{WEBAPP_NAME}.azurewebsites.net` (from dev environment)
- Staging: `https://{WEBAPP_NAME}.azurewebsites.net` (from staging environment)
- Production: `https://{WEBAPP_NAME}.azurewebsites.net` (from production environment)

### GitHub Pages

**Workflow**: `jekyll-gh-pages.yml`

**Architecture**:
- **Hosting**: GitHub Pages (static site hosting)
- **Generator**: Jekyll (Ruby-based)
- **Build Output**: `./_site` directory
- **Artifact Handoff**: Build job → Deploy job

**Deployment Flow**:
1. Build Jekyll site with Ruby 3.1
2. Configure GitHub Pages base path
3. Upload built site as artifact
4. Deploy artifact to GitHub Pages
5. Site available at github.io URL

**Current Configuration**:
- **Ruby Version**: 3.1 (hardcoded)
- **Jekyll Environment**: `JEKYLL_ENV=production`
- **Caching**: Bundler cache enabled
- **Concurrency**: Single deployment at a time

**Accessing Your Site**:
- URL provided in deployment job output
- Typically: `https://{username}.github.io/{repository}/`
- Check: Settings → Pages for the live URL

---

## Troubleshooting

### Common Issues

#### Container Workflow

**Issue**: `Missing vars.ACR_NAME` error

**Solution**: 
1. Go to Settings → Secrets and variables → Actions → Variables
2. Add `ACR_NAME` with your Azure Container Registry name
3. Ensure it's set for the correct environment if using environment-specific values

---

**Issue**: Azure login fails with OIDC

**Solution**:
1. Verify secrets are correct:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
2. Check Azure AD federated credentials configuration
3. Ensure app registration has required Azure RBAC roles:
   - `AcrPush` role on ACR
   - `Contributor` or `Website Contributor` on Web App

---

**Issue**: `az acr build` fails

**Possible Causes**:
- ACR name is incorrect or doesn't exist
- OIDC identity lacks `AcrPush` role
- Dockerfile syntax errors
- Network connectivity to ACR

**Solution**:
1. Verify ACR exists: `az acr show -n {ACR_NAME}`
2. Check role assignments in Azure Portal
3. Test Dockerfile locally: `docker build -f ./src/Dockerfile ./src`
4. Review build logs in workflow run

---

**Issue**: Deployment succeeds but app doesn't work

**Solution**:
1. Check app is listening on port 8080 (configured in workflow)
2. View Web App logs in Azure Portal
3. Verify container image pulled successfully
4. Check app settings and connection strings in Azure
5. Test image locally: 
   ```bash
   docker run -p 8080:8080 {ACR_NAME}.azurecr.io/zavastorefront:{TAG}
   curl http://localhost:8080
   ```

---

**Issue**: Workflow runs on unrelated changes

**Solution**: Path filters are configured to only run on relevant changes. If you need to adjust:
```yaml
paths:
  - 'src/**'
  - '**/Dockerfile'
  # Add or remove paths as needed
```

#### Jekyll Workflow

**Issue**: Jekyll build fails

**Common Causes**:
- Missing dependencies in `Gemfile`
- Invalid frontmatter in markdown files
- Ruby version incompatibility

**Solution**:
1. Test locally: `bundle install && bundle exec jekyll build`
2. Check build logs for specific errors
3. Ensure all gems are listed in `Gemfile`
4. Consider adding `.ruby-version` file for consistency

---

**Issue**: GitHub Pages deployment fails

**Solution**:
1. Verify Pages is enabled: Settings → Pages
2. Ensure source is set to "GitHub Actions" (not "Deploy from a branch")
3. Check that workflow has pages permissions:
   ```yaml
   permissions:
     pages: write
     id-token: write
   ```

---

**Issue**: Site deploys but shows 404

**Solution**:
1. Check base URL configuration in Jekyll `_config.yml`
2. Verify GitHub Pages URL in Settings → Pages
3. Ensure workflow uses correct base path:
   ```yaml
   run: bundle exec jekyll build --baseurl "${{ steps.pages.outputs.base_path }}"
   ```

---

**Issue**: Changes not appearing on site

**Solution**:
1. Check workflow run completed successfully
2. Clear browser cache (GitHub Pages may cache content)
3. Wait 1-2 minutes for CDN propagation
4. Verify correct branch is configured in Settings → Pages

### Debugging Tips

**Enable Debug Logging**:
1. Go to Settings → Secrets and variables → Actions
2. Add repository secret: `ACTIONS_STEP_DEBUG` = `true`
3. Re-run workflow to see detailed logs

**View Raw Logs**:
- Click any workflow run
- Click any job
- Click "..." → "View raw logs"
- Search for specific errors or commands

**Test Locally**:

Container builds:
```bash
# Test Docker build
docker build -f ./src/Dockerfile ./src -t test:latest

# Test container runs
docker run -p 8080:8080 test:latest
```

Jekyll builds:
```bash
# Install dependencies
bundle install

# Build site
bundle exec jekyll build

# Serve locally
bundle exec jekyll serve
```

**Re-run Failed Jobs**:
- Click "Re-run failed jobs" in workflow run
- Or "Re-run all jobs" to start fresh

**Manual Workflow Testing**:
- Use workflow_dispatch triggers to test without pushing
- Test with different inputs/environments
- Verify changes before merging to main

---

## Recommendations for Improvement

> **Note**: The following are recommendations to enhance security, reliability, and maintainability. They are not currently implemented.

### High Priority (Security & Reliability)

#### 1. Pin Actions to Commit SHAs

**Current State**: Actions use version tags (`@v4`, `@v2`)

**Recommended**:
```yaml
# Container workflow
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: azure/login@92a5484dfca0f8b0a63a5c8edc2e5d92d8c1e6b5  # v2.0.0

# Jekyll workflow
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: ruby/setup-ruby@d4526a5586a35e7e4634e1f91e636b6a731b6201  # v1.171.0
- uses: actions/configure-pages@983bd608fc740d2b4e3d656df5ac66d4cf989ebc  # v4.0.0
- uses: actions/upload-pages-artifact@56afc609e74202658d3ffba0e8f6dda462b719fa  # v3.0.1
- uses: actions/deploy-pages@d6db90e31b3c6c9a9f233c64b8ddce1a65ee64b4  # v4.0.5
```

**Benefit**: Prevents supply chain attacks via compromised action tags

**Effort**: Low - can be automated with Dependabot

#### 2. Add Container Vulnerability Scanning

**Recommended Addition** (add to container workflow after build step):

```yaml
- name: Scan container image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ vars.ACR_NAME }}.azurecr.io/zavastorefront:${{ steps.vars.outputs.IMAGE_TAG }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
  env:
    AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: 'trivy-results.sarif'
```

**Benefit**: Identifies vulnerabilities before production deployment

**Effort**: Medium

#### 3. Add Deployment Health Checks

**Recommended Addition** (add to container workflow after deployment):

```yaml
- name: Verify deployment health
  run: |
    echo "Waiting for app to start..."
    sleep 30
    
    for i in {1..30}; do
      if curl -f -s "https://${{ vars.WEBAPP_NAME }}.azurewebsites.net/health" > /dev/null; then
        echo "✅ Deployment successful - health check passed"
        exit 0
      fi
      echo "Attempt $i/30 failed, retrying..."
      sleep 10
    done
    
    echo "❌ Deployment verification failed - health check did not respond"
    exit 1
```

**Benefit**: Catches deployment failures immediately

**Effort**: Low (requires `/health` endpoint in app)

#### 4. Enable CodeQL Scanning

**Create new workflow**: `.github/workflows/codeql-analysis.yml`

```yaml
name: "CodeQL Security Scan"

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday

jobs:
  analyze:
    name: Analyze Code
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    strategy:
      matrix:
        language: [ 'javascript', 'python' ]  # Adjust to your languages

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

**Benefit**: Identifies code-level security vulnerabilities

**Effort**: Medium

### Medium Priority (Quality & Maintainability)

#### 5. Add Automated Testing

**Recommended Addition** (add job before deployment):

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: |
          # Add your test commands
          npm test
          # or: pytest
          # or: dotnet test

  build_and_deploy:
    needs: test  # Only deploy if tests pass
    runs-on: ubuntu-latest
    # ... rest of workflow
```

**Benefit**: Catches bugs before deployment

#### 6. Add Concurrency Control to Container Workflow

**Recommended Addition**:

```yaml
concurrency:
  group: deploy-${{ inputs.environment || 'dev' }}
  cancel-in-progress: false  # Let deployments complete
```

**Benefit**: Prevents conflicting deployments

#### 7. Use .ruby-version File

**Current**: Ruby version hardcoded to 3.1

**Recommended**: Create `.ruby-version` file:
```
3.1.4
```

Update workflow:
```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    bundler-cache: true  # Automatically uses .ruby-version
```

**Benefit**: Consistent Ruby version across local dev and CI

#### 8. Implement Rollback Capability

**Create new workflow**: `.github/workflows/rollback-container.yml`

```yaml
name: Rollback Container Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - dev
          - staging
          - production
      image_tag:
        description: 'Previous image tag to rollback to'
        required: true
        type: string

permissions:
  id-token: write
  contents: read

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Rollback to previous version
        run: |
          ACR_LOGIN_SERVER=$(az acr show -n "${{ vars.ACR_NAME }}" --query loginServer -o tsv)
          FULL_IMAGE="${ACR_LOGIN_SERVER}/zavastorefront:${{ inputs.image_tag }}"
          
          az webapp config container set \
            --resource-group "${{ vars.AZURE_RESOURCE_GROUP }}" \
            --name "${{ vars.WEBAPP_NAME }}" \
            --docker-custom-image-name "$FULL_IMAGE"
          
          az webapp restart \
            --resource-group "${{ vars.AZURE_RESOURCE_GROUP }}" \
            --name "${{ vars.WEBAPP_NAME }}"
```

**Benefit**: Quick recovery from bad deployments

### Low Priority (Optimization)

#### 9. Enable Dependabot

**Create**: `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  
  - package-ecosystem: "docker"
    directory: "/src"
    schedule:
      interval: "weekly"
  
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Benefit**: Automated dependency updates and security patches

#### 10. Add Deployment Notifications

**Recommended Addition** (add to end of deployment workflows):

```yaml
- name: Notify deployment status
  if: always()
  run: |
    if [ "${{ job.status }}" == "success" ]; then
      # Send success notification
      curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
        -H 'Content-Type: application/json' \
        -d '{"text":"✅ Deployment to ${{ inputs.environment || 'dev' }} successful!"}'
    else
      # Send failure notification
      curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
        -H 'Content-Type: application/json' \
        -d '{"text":"❌ Deployment to ${{ inputs.environment || 'dev' }} failed!"}'
    fi
```

**Benefit**: Team awareness of deployment status

---

## Quick Reference

### Manual Deployment Checklist

**To deploy container to Azure**:
1. ✅ Ensure all secrets are configured
2. ✅ Verify environment variables are set
3. ✅ Go to Actions → "Build and deploy container to App Service"
4. ✅ Click "Run workflow"
5. ✅ Select environment (dev/staging/production)
6. ✅ Click "Run workflow"
7. ✅ Monitor workflow execution
8. ✅ Verify deployment at `https://{WEBAPP_NAME}.azurewebsites.net`

**To deploy Jekyll site**:
1. ✅ Ensure GitHub Pages is configured
2. ✅ Go to Actions → "Deploy Jekyll with GitHub Pages"
3. ✅ Click "Run workflow"
4. ✅ Click "Run workflow" (no inputs)
5. ✅ Monitor workflow execution
6. ✅ Check site at Pages URL (shown in deployment job)

### Important Files

- **Workflows**: `.github/workflows/`
  - `deploy-appservice-container.yml` - Azure container deployment
  - `jekyll-gh-pages.yml` - GitHub Pages deployment
- **Source Code**: `./src/` - Application source
- **Dockerfile**: `./src/Dockerfile` - Container definition
- **Jekyll Config**: `./_config.yml` - Jekyll configuration
- **Ruby Gems**: `./Gemfile` - Ruby dependencies

### Required Azure Resources

For container deployment:
- ✅ Azure Container Registry (ACR)
- ✅ Azure App Service (Web App for Containers)
- ✅ Azure AD App Registration (for OIDC)
- ✅ Resource Group

### Useful Commands

**View workflow runs**:
```bash
gh workflow list
gh run list --workflow="deploy-appservice-container.yml"
gh run view <run-id>
```

**Trigger workflow manually**:
```bash
gh workflow run deploy-appservice-container.yml -f environment=dev
gh workflow run jekyll-gh-pages.yml
```

**View logs**:
```bash
gh run view <run-id> --log
```

**Check Azure deployment**:
```bash
az webapp show --name <WEBAPP_NAME> --resource-group <RESOURCE_GROUP>
az webapp log tail --name <WEBAPP_NAME> --resource-group <RESOURCE_GROUP>
```

---

## Additional Resources

### GitHub Actions Documentation
- [GitHub Actions Overview](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [Environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments)
- [OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)

### Azure Resources
- [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Azure App Service](https://docs.microsoft.com/en-us/azure/app-service/)
- [Web App for Containers](https://docs.microsoft.com/en-us/azure/app-service/quickstart-custom-container)

### GitHub Pages
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [Publishing with GitHub Actions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site#publishing-with-a-custom-github-actions-workflow)

---

## Getting Help

**For workflow issues**:
1. Check this documentation
2. Review workflow run logs in Actions tab
3. Test locally when possible
4. Check GitHub Actions status: https://www.githubstatus.com/

**For Azure issues**:
1. Check Azure Portal for resource status
2. Review App Service logs
3. Verify RBAC permissions
4. Check Azure service health

**For Jekyll issues**:
1. Test locally: `bundle exec jekyll build`
2. Check build logs in Actions tab
3. Review Jekyll documentation
4. Verify Gemfile dependencies

---

*Last updated: Based on repository analysis*
*Workflows: 2 active | Deployment targets: Azure App Service, GitHub Pages*
