# GitHub Actions Workflows Analysis

## Summary

- **Total Workflows**: 2
- **Total Jobs**: 3
- **Deployment Targets**: Azure App Service (Web App for Containers), GitHub Pages
- **Security Features**: OIDC authentication, explicit permissions, version-pinned actions

---

## Workflows

### 1. Build and deploy container to App Service

**File**: `.github/workflows/deploy-appservice-container.yml`

**Purpose**: Builds a Docker container image in Azure Container Registry (ACR) and deploys it to Azure App Service (Web App for Containers). This is a complete CI/CD pipeline for containerized applications.

#### Triggers

- **workflow_dispatch**: Manual trigger with environment selection
  - Input: `environment` (choice: dev, staging, production)
  - Required: true
  - Default: 'dev'
  
- **push**: Automatic trigger on main branch
  - Branches: `main`
  - Path filters:
    - `src/**`
    - `**/Dockerfile`, `src/Dockerfile`
    - `**/.dockerignore`, `.dockerignore`
    - `**/docker-compose*.yml`, `docker-compose*.yml`
    - `infra/deploy-container.ps1`
  
- **pull_request**: Validation on PRs to main
  - Branches: `main`
  - Same path filters as push trigger

#### Jobs

**1. build_and_deploy**
- **Runner**: `ubuntu-latest`
- **Environment**: Dynamic - uses workflow_dispatch input or defaults to 'dev'
- **Dependencies**: None (single job workflow)
- **Concurrency**: No explicit concurrency control

**Key Steps**:

1. **Checkout** (`actions/checkout@v4`)
   - Fetches full git history (`fetch-depth: 0`)
   - Good for versioning and changelog generation

2. **Azure login (OIDC)** (`azure/login@v2`)
   - Uses OpenID Connect for secure authentication
   - Requires secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - No long-lived credentials stored

3. **Resolve image tag** (custom script)
   - Creates short SHA tag from commit: `${GITHUB_SHA::7}`
   - Creates stable environment tag: dev/staging/production
   - Uses output variables for subsequent steps

4. **Build in ACR** (cloud build)
   - Uses `az acr build` for cloud-based Docker builds
   - No local Docker daemon required (faster, cleaner)
   - Tags image with both commit SHA and environment
   - Requires environment variable: `ACR_NAME`
   - Validates required variables before execution

5. **Deploy to App Service** (custom script)
   - Updates Web App container configuration
   - Sets custom image from ACR
   - Configures port mapping (8080)
   - Restarts the app to apply changes
   - Requires environment variables: `RESOURCE_GROUP`, `WEBAPP_NAME`, `ACR_NAME`
   - Includes validation checks for all required variables

#### Security Configuration

**Permissions**:
```yaml
permissions:
  id-token: write  # Required for OIDC authentication
  contents: read   # Read repository contents
```
- **Excellent**: Minimal permissions following least-privilege principle
- Only grants what's necessary for the workflow

**OIDC (OpenID Connect)**:
- ✅ **Enabled**: Uses Azure OIDC for authentication
- ✅ **No stored credentials**: Eliminates long-lived secrets
- ✅ **Federated identity**: Short-lived tokens generated per workflow run

**Secrets Used**:
- `AZURE_CLIENT_ID` - Azure AD application (client) ID
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

**Environment Variables (from GitHub Environments/Variables)**:
- `ACR_NAME` - Azure Container Registry name
- `AZURE_RESOURCE_GROUP` - Resource group for deployment
- `WEBAPP_NAME` - App Service web app name

**Action Version Pinning**:
- ⚠️ `actions/checkout@v4` - **Tag-based** (should use commit SHA)
- ⚠️ `azure/login@v2` - **Tag-based** (should use commit SHA)

**Security Concerns**:
1. Actions pinned to major version tags (`@v4`, `@v2`) rather than commit SHAs
   - **Risk**: Tags can be moved/updated, potentially introducing malicious code
   - **Recommendation**: Pin to specific commit SHAs for maximum security
2. No dependency scanning or vulnerability checks in the container build
3. No code scanning or SAST (Static Application Security Testing)

#### CD Target Choices

**Primary Target**: **Azure App Service** (Web App for Containers)

**Architecture**:
- Container Registry: Azure Container Registry (ACR)
- Compute: Azure App Service (PaaS)
- Container runtime: Linux containers on App Service

**Deployment Strategy**:
- Cloud-native build (ACR Tasks)
- Direct deployment via Azure CLI
- Image tagging strategy: commit SHA + environment label
- Port configuration: 8080 (standard for non-root containers)

**Environment Strategy**:
- Multi-environment support: dev, staging, production
- Environment-specific configurations via GitHub Environments
- Manual approval gates possible (GitHub Environment protection rules)

---

### 2. Deploy Jekyll with GitHub Pages dependencies preinstalled

**File**: `.github/workflows/jekyll-gh-pages.yml`

**Purpose**: Builds a Jekyll static site and deploys it to GitHub Pages. This is a standard documentation/website deployment pipeline.

#### Triggers

- **push**: Automatic deployment on main branch
  - Branches: `["main"]`
  - No path filters (runs on any change)
  
- **workflow_dispatch**: Manual trigger
  - No inputs required

#### Jobs

**1. build**
- **Runner**: `ubuntu-latest`
- **Dependencies**: None
- **Purpose**: Compile Jekyll site to static HTML

**Key Steps**:

1. **Checkout** (`actions/checkout@v4`)
   - Default shallow clone (no depth specified)

2. **Setup Ruby** (`ruby/setup-ruby@v1`)
   - Ruby version: 3.1 (hardcoded, but comment suggests `.ruby-version` file)
   - Bundler caching enabled (speeds up subsequent runs)
   - Cache version: 0 (can be incremented to invalidate cache)

3. **Setup Pages** (`actions/configure-pages@v4`)
   - Configures GitHub Pages settings
   - Provides base path for Jekyll

4. **Build with Jekyll** (custom command)
   - Command: `bundle exec jekyll build --baseurl "${{ steps.pages.outputs.base_path }}"`
   - Environment: JEKYLL_ENV=production
   - Output directory: `./_site` (default)

5. **Upload artifact** (`actions/upload-pages-artifact@v3`)
   - Uploads built site for deployment job

**2. deploy**
- **Runner**: `ubuntu-latest`
- **Dependencies**: Depends on `build` job (`needs: build`)
- **Environment**: `github-pages` (with URL output)
- **Purpose**: Deploy built site to GitHub Pages

**Key Steps**:

1. **Deploy to GitHub Pages** (`actions/deploy-pages@v4`)
   - Uses artifact from build job
   - Outputs page URL for reference

#### Security Configuration

**Permissions**:
```yaml
permissions:
  contents: read    # Read repository contents
  pages: write      # Deploy to GitHub Pages
  id-token: write   # Required for GitHub Pages deployment attestation
```
- **Good**: Explicit permissions for Pages deployment
- Includes `id-token: write` for deployment attestation/provenance

**Concurrency Control**:
```yaml
concurrency:
  group: "pages"
  cancel-in-progress: true
```
- **Excellent**: Prevents multiple concurrent deployments
- Cancels in-progress deployments when new one starts
- Avoids race conditions and resource conflicts

**Secrets Used**:
- None (uses implicit `GITHUB_TOKEN`)

**Action Version Pinning**:
- ⚠️ `actions/checkout@v4` - **Tag-based** (should use commit SHA)
- ⚠️ `ruby/setup-ruby@v1` - **Tag-based** (should use commit SHA)
- ⚠️ `actions/configure-pages@v4` - **Tag-based** (should use commit SHA)
- ⚠️ `actions/upload-pages-artifact@v3` - **Tag-based** (should use commit SHA)
- ⚠️ `actions/deploy-pages@v4` - **Tag-based** (should use commit SHA)

**Security Concerns**:
1. All actions pinned to major/minor version tags rather than commit SHAs
   - **Risk**: Version tags can be updated, potentially introducing vulnerabilities
   - **Recommendation**: Pin to specific commit SHAs
2. Ruby version hardcoded (3.1) - may become outdated
   - Comment suggests `.ruby-version` file should be used instead
3. No dependency scanning for Ruby gems
4. No validation of Jekyll output before deployment

#### CD Target Choices

**Primary Target**: **GitHub Pages**

**Architecture**:
- Hosting: GitHub Pages (static site hosting)
- Build: Jekyll (Ruby-based static site generator)
- Artifact storage: GitHub Actions artifacts

**Deployment Strategy**:
- Two-phase deployment: build then deploy
- Artifact-based handoff between jobs
- Automatic URL generation from GitHub Pages environment
- Concurrency control prevents deployment conflicts

**Caching Strategy**:
- Ruby gems cached via `bundler-cache: true`
- Cache versioning supported for invalidation

---

## Cross-Workflow Patterns

### Best Practices Observed

1. **✅ Explicit Permissions**: Both workflows define minimal required permissions
   - Follows least-privilege security principle
   - Better than default permissive `GITHUB_TOKEN`

2. **✅ OIDC Authentication**: Container deployment uses OIDC (no long-lived credentials)
   - Modern, secure authentication method
   - Short-lived tokens reduce attack surface

3. **✅ Path Filtering**: Container workflow uses path filters to avoid unnecessary runs
   - Saves compute resources
   - Faster feedback for unrelated changes

4. **✅ Manual Triggers**: Both support `workflow_dispatch` for manual control
   - Useful for testing and emergency deployments

5. **✅ Environment Strategy**: Container workflow uses GitHub Environments
   - Enables approval gates and environment-specific secrets
   - Clear separation between dev/staging/production

6. **✅ Concurrency Control**: Jekyll workflow prevents concurrent deployments
   - Avoids race conditions
   - Ensures consistent state

7. **✅ Job Dependencies**: Jekyll workflow uses `needs:` for proper job ordering
   - Build must complete before deploy
   - Clear dependency chain

8. **✅ Variable Validation**: Container workflow validates required variables
   - Fails fast with clear error messages
   - Prevents partial deployments

### Areas for Improvement

1. **⚠️ Action Version Pinning**
   - **Issue**: All actions use tag-based versioning (`@v4`, `@v2`, `@v1`)
   - **Risk**: Tags can be moved, potentially introducing malicious code
   - **Recommendation**: Pin actions to commit SHAs for immutability
   - **Example**: `actions/checkout@v4` → `actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11` (v4.1.1)

2. **⚠️ Missing Security Scanning**
   - **Issue**: No dependency scanning, code scanning, or container scanning
   - **Recommendation**: Add security scanning steps
   - **Suggested Actions**:
     - `github/codeql-action` for code scanning
     - `aquasecurity/trivy-action` for container vulnerability scanning
     - Dependabot for dependency updates

3. **⚠️ No Test Coverage**
   - **Issue**: Container workflow builds and deploys without testing
   - **Recommendation**: Add test jobs before deployment
   - **Suggested Steps**:
     - Unit tests
     - Integration tests
     - Smoke tests after deployment

4. **⚠️ Hardcoded Ruby Version**
   - **Issue**: Jekyll workflow hardcodes Ruby 3.1
   - **Recommendation**: Use `.ruby-version` file (as comment suggests)
   - **Benefit**: Consistent version across local dev and CI

5. **⚠️ No Rollback Strategy**
   - **Issue**: No easy way to rollback failed deployments
   - **Recommendation**: 
     - Tag container images with version/release info
     - Keep previous versions in ACR
     - Add rollback workflow

6. **⚠️ Limited Observability**
   - **Issue**: No logging/monitoring integration
   - **Recommendation**: 
     - Add Azure Application Insights integration
     - Log deployment events
     - Add health check verification post-deployment

---

## Security Summary

### Overall Security Posture: **Good** ⭐⭐⭐⭐☆

**Strengths**:
- ✅ OIDC authentication (container workflow) - no long-lived credentials
- ✅ Explicit least-privilege permissions on workflows
- ✅ No secrets in code (uses GitHub Secrets and Variables)
- ✅ Environment-based deployment strategy with potential for approval gates
- ✅ Concurrency control prevents race conditions

**Critical Recommendations**:

1. **HIGH PRIORITY: Pin Actions to Commit SHAs**
   ```yaml
   # Instead of:
   uses: actions/checkout@v4
   
   # Use:
   uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
   ```
   **Impact**: Prevents supply chain attacks via compromised action tags
   **Effort**: Low (can be automated with Dependabot or renovate)

2. **HIGH PRIORITY: Add Container Scanning**
   ```yaml
   - name: Scan container image
     uses: aquasecurity/trivy-action@master
     with:
       image-ref: ${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_REPO }}:${{ steps.vars.outputs.IMAGE_TAG }}
       format: 'sarif'
       output: 'trivy-results.sarif'
   
   - name: Upload Trivy results to GitHub Security
     uses: github/codeql-action/upload-sarif@v2
     with:
       sarif_file: 'trivy-results.sarif'
   ```
   **Impact**: Identifies vulnerabilities before production deployment
   **Effort**: Medium

3. **MEDIUM PRIORITY: Enable CodeQL Scanning**
   - Add CodeQL workflow for static analysis
   - Scan source code for security vulnerabilities
   - Integrate with GitHub Security tab

4. **MEDIUM PRIORITY: Add Deployment Verification**
   ```yaml
   - name: Verify deployment
     run: |
       for i in {1..30}; do
         if curl -f "https://${{ vars.WEBAPP_NAME }}.azurewebsites.net/health"; then
           echo "Deployment successful"
           exit 0
         fi
         sleep 10
       done
       echo "Deployment verification failed"
       exit 1
   ```
   **Impact**: Catches deployment failures early
   **Effort**: Low

5. **LOW PRIORITY: Enable Dependabot**
   - Configure Dependabot for GitHub Actions
   - Automate action version updates
   - Monitor for security advisories

---

## Deployment Targets Summary

### Azure App Service (Web App for Containers)
- **Workflow**: deploy-appservice-container.yml
- **Type**: PaaS (Platform as a Service)
- **Container Registry**: Azure Container Registry (ACR)
- **Environments**: dev, staging, production
- **Authentication**: OIDC (OpenID Connect)
- **Deployment Method**: Azure CLI (`az webapp config container set`)

### GitHub Pages
- **Workflow**: jekyll-gh-pages.yml
- **Type**: Static Site Hosting
- **Generator**: Jekyll (Ruby)
- **Environments**: github-pages (single environment)
- **Authentication**: Implicit GitHub token
- **Deployment Method**: GitHub Pages action

---

## Action Inventory

### Used Actions (with current versions)

| Action | Current Version | Latest SHA (example) | Purpose |
|--------|-----------------|----------------------|---------|
| `actions/checkout` | v4 | `b4ffde65...` | Repository checkout |
| `azure/login` | v2 | `92a5484d...` | Azure authentication |
| `ruby/setup-ruby` | v1 | `d4526a55...` | Ruby environment setup |
| `actions/configure-pages` | v4 | `983bd608...` | GitHub Pages configuration |
| `actions/upload-pages-artifact` | v3 | `56afc609...` | Upload Pages artifact |
| `actions/deploy-pages` | v4 | `d6db90e3...` | Deploy to GitHub Pages |

**Note**: All actions should be pinned to commit SHAs for security. The table above shows tag-based versions currently in use.

---

## Workflow Health Metrics

| Metric | Container Workflow | Jekyll Workflow |
|--------|-------------------|-----------------|
| **Trigger Types** | 3 (push, PR, manual) | 2 (push, manual) |
| **Jobs** | 1 | 2 |
| **Permissions Scope** | ✅ Minimal | ✅ Minimal |
| **OIDC Auth** | ✅ Yes | N/A |
| **Concurrency Control** | ❌ No | ✅ Yes |
| **Caching** | ❌ No | ✅ Yes (Ruby gems) |
| **Path Filters** | ✅ Yes | ❌ No |
| **Environment Strategy** | ✅ Multi-env | ⚠️ Single |
| **Action Pinning** | ⚠️ Tags only | ⚠️ Tags only |
| **Security Scanning** | ❌ No | ❌ No |
| **Test Coverage** | ❌ No | ❌ No |

---

## Recommendations Priority Matrix

### High Priority (Security & Reliability)
1. ✅ Pin all actions to commit SHAs
2. ✅ Add container vulnerability scanning (Trivy)
3. ✅ Enable CodeQL for source code scanning
4. ✅ Add deployment health checks

### Medium Priority (Quality & Maintainability)
5. ⚠️ Add unit and integration tests
6. ⚠️ Implement rollback capability
7. ⚠️ Add concurrency control to container workflow
8. ⚠️ Use `.ruby-version` file in Jekyll workflow

### Low Priority (Optimization)
9. 📝 Enable Dependabot for automated updates
10. 📝 Add build caching for faster builds
11. 📝 Implement deployment notifications (Slack, Teams)
12. 📝 Add performance testing

---

## Conclusion

Both workflows demonstrate **good security fundamentals** with explicit permissions and modern authentication (OIDC). However, there's significant room for improvement in **supply chain security** (action pinning) and **application security** (scanning, testing).

The workflows are production-ready but would benefit from enhanced security scanning and testing before being used for critical deployments.

**Key Action Items**:
1. Pin all GitHub Actions to commit SHAs immediately
2. Add Trivy container scanning to the container workflow
3. Enable CodeQL scanning for the repository
4. Add automated tests before deployment
5. Implement deployment verification and health checks
