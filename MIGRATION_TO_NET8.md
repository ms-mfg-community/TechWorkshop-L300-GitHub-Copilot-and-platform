# Migration from .NET 6 to .NET 8 LTS

## Overview

This document describes the migration of the Zava Storefront application from .NET 6 to .NET 8 LTS (Long-Term Support), completed in January 2026. The migration follows Microsoft's official guidance and ensures alignment with Microsoft Cloud Platform (MCP) best practices.

## Migration Date

January 14, 2026

## .NET Version Information

- **Previous Version**: .NET 6.0
- **Current Version**: .NET 8.0 (LTS)
- **LTS End of Support**: November 10, 2026 (for .NET 6)
- **LTS End of Support**: November 10, 2029 (for .NET 8)

## Why .NET 8?

.NET 8 is the latest Long-Term Support (LTS) release from Microsoft as of January 2026, offering:

- **Extended Support**: 3 years of support until November 2029
- **Performance Improvements**: Significant performance enhancements across the runtime and libraries
- **Security Updates**: Latest security patches and improvements
- **Modern Features**: Access to new C# language features and runtime capabilities
- **Cloud-Native**: Enhanced support for containerization and Azure services

## Files Modified

### 1. Project Configuration
- **File**: `src/ZavaStorefront.csproj`
- **Change**: Updated `<TargetFramework>` from `net6.0` to `net8.0`

### 2. Docker Configuration
- **File**: `src/Dockerfile`
- **Changes**: 
  - Updated build image from `mcr.microsoft.com/dotnet/sdk:6.0` to `mcr.microsoft.com/dotnet/sdk:8.0`
  - Updated runtime image from `mcr.microsoft.com/dotnet/aspnet:6.0` to `mcr.microsoft.com/dotnet/aspnet:8.0`

### 3. Documentation
- **File**: `src/README.md`
- **Change**: Updated technology stack section to reflect .NET 8 (LTS)
- **File**: `docs/04_github_advanced_security/04_03.md`
- **Change**: Added note that .NET 6 to .NET 8 upgrade has been completed

## Breaking Changes

Based on the [official migration guide](https://learn.microsoft.com/en-us/dotnet/core/compatibility/6.0-to-8.0), the following areas were reviewed:

### ASP.NET Core
- No breaking changes affecting this application
- The application uses standard ASP.NET Core MVC patterns that are fully compatible with .NET 8

### Runtime Behavior
- No breaking changes affecting this application
- The application does not rely on any deprecated APIs or behaviors

### Nullable Reference Types
- Pre-existing nullable reference warnings remain (not introduced by the migration)
- These warnings existed in .NET 6 and are not related to the version upgrade

## Compatibility Notes

The Zava Storefront application successfully migrated to .NET 8 with no code changes required:

- **Controllers**: No changes needed - ASP.NET Core MVC patterns fully compatible
- **Services**: No changes needed - Dependency injection and service patterns unchanged
- **Models**: No changes needed - Data models remain compatible
- **Session Management**: No changes needed - Session middleware unchanged
- **Static Files**: No changes needed - Static file serving unchanged

## Testing Performed

1. **Build Verification**
   - ✅ Project builds successfully with .NET 8 SDK
   - ✅ No new compilation errors introduced
   - ✅ All warnings are pre-existing (nullable reference types)

2. **Runtime Testing**
   - Application runs successfully on .NET 8 runtime
   - All features functional (product listing, cart, checkout)

3. **Container Testing**
   - Docker image builds successfully with .NET 8 base images
   - Container runs and serves application correctly
   - Azure Container Registry (ACR) build compatibility confirmed

## CI/CD Considerations

The existing CI/CD pipeline in `.github/workflows/deploy-appservice-container.yml` continues to work without modification because:

- The workflow uses `az acr build` which pulls the SDK version from the Dockerfile
- No workflow changes were needed as the Docker build handles the version upgrade
- Azure App Service for Linux automatically supports .NET 8 runtime

## References

This migration was performed following official Microsoft documentation and guidance:

1. **Microsoft .NET Documentation**
   - Official Site: https://learn.microsoft.com/en-us/dotnet/

2. **LTS Release Policy**
   - Documentation: https://learn.microsoft.com/en-us/dotnet/core/tools/lts-releases
   - .NET Support Policy: https://dotnet.microsoft.com/platform/support/policy/dotnet-core

3. **Migration Guide**
   - .NET 6 to .NET 8: https://learn.microsoft.com/en-us/dotnet/core/compatibility/6.0-to-8.0
   - Breaking Changes: https://learn.microsoft.com/en-us/dotnet/core/compatibility/

4. **Azure and Cloud Platform**
   - Azure App Service .NET Support: https://learn.microsoft.com/en-us/azure/app-service/
   - Microsoft Cloud Adoption Framework: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/

5. **Container Support**
   - .NET Container Images: https://mcr.microsoft.com/product/dotnet/sdk
   - .NET on Docker: https://learn.microsoft.com/en-us/dotnet/core/docker/introduction

## Future Considerations

### .NET 9 and Beyond

While .NET 9 is available (released in November 2024), it is a Standard Term Support (STS) release with only 18 months of support. Organizations requiring stability and long-term support should remain on .NET 8 LTS until .NET 10 LTS is released (expected November 2025).

### Recommended Upgrade Path

- **Current**: .NET 8 (LTS) - Supported until November 2029
- **Next LTS**: .NET 10 (expected November 2025) - Plan to evaluate in late 2025/early 2026
- **Support Timeline**: Plan next upgrade approximately 6-12 months before .NET 8 end of support

## Support and Troubleshooting

If issues arise related to the .NET 8 upgrade:

1. Check the [.NET 8 release notes](https://github.com/dotnet/core/tree/main/release-notes/8.0)
2. Review the [breaking changes documentation](https://learn.microsoft.com/en-us/dotnet/core/compatibility/8.0)
3. Consult the [.NET discussion forum](https://github.com/dotnet/runtime/discussions)
4. Review Azure-specific guidance in the [Azure documentation](https://learn.microsoft.com/en-us/azure/)

## Conclusion

The migration from .NET 6 to .NET 8 LTS was completed successfully with minimal changes required. The application builds, runs, and deploys correctly on the new runtime. This upgrade ensures the Zava Storefront application remains on a supported, secure, and performant platform through November 2029.
