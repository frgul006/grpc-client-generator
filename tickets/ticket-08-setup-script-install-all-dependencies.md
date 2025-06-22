# Ticket 08: Install Dependencies Across All Packages

## Epic/Scope

setup-script

## What

Enhance the `lab setup` command to install dependencies across all package.json files in the monorepo, not just the product-api package. Currently, the setup only installs dependencies for `apis/product-api`, leaving other packages without their required dependencies.

## Why

- **Complete Environment Setup**: All packages need their dependencies installed for the development environment to function properly
- **Monorepo Support**: The repository contains multiple packages (APIs, libraries, services) that each have their own dependencies
- **Developer Experience**: Developers expect `lab setup` to fully prepare their environment for all project components
- **Build Pipeline**: Other packages (like `libs/grpc-client-generator`) may be dependencies for the APIs and services
- **Consistency**: Setup should handle all packages uniformly rather than hardcoding specific paths

The current implementation in `cli/lib/setup/infrastructure.sh:68-99` only handles the product-api directory, leaving developers to manually install dependencies for other packages.

## How

### 1. Analyze Current Implementation

- Review `install_dependencies()` function in `cli/lib/setup/infrastructure.sh`
- Understand current npm registry configuration and retry logic
- Identify reusable patterns from existing implementation

### 2. Discover All Package Directories

- Implement function to find all directories containing `package.json` files
- Exclude `node_modules` and `registry` directories from discovery
- Return directories in dependency order (libraries first, then APIs/services)

### 3. Enhance `install_dependencies()` Function

- Replace hardcoded `apis/product-api` path with dynamic discovery
- Install dependencies for each package directory found
- Maintain existing Verdaccio registry configuration and retry logic
- Add progress tracking for multiple package installations

### 4. Update Progress Reporting

- Modify log messages to indicate which package is being processed
- Update the setup summary to show dependency status for all packages
- Add specific error handling for individual package failures

### 5. Testing and Validation

- Test with clean environment (no existing node_modules)
- Verify all packages get their dependencies installed correctly
- Ensure proper error handling when individual packages fail
- Test that existing functionality for product-api remains unchanged

## Definition of Done

- [ ] `install_dependencies()` function discovers all package.json files in the repository
- [ ] Dependencies are installed for all discovered packages (root, apis/*, libs/*, services/*)
- [ ] Installation order respects potential dependencies (libs before apis/services)
- [ ] Progress logging shows which package is currently being processed
- [ ] Setup summary reports dependency status for all packages, not just product-api
- [ ] Error handling gracefully handles individual package failures without stopping entire setup
- [ ] Existing npm registry configuration and retry logic is preserved
- [ ] Function properly excludes node_modules and registry directories from processing
- [ ] All existing setup functionality continues to work unchanged

## Priority

High

## Estimated Effort

Medium (2-3 hours)

## Dependencies

- None

## Risks

- Dependency installation order may matter for some packages
- Some packages might have different npm registry requirements
- Installation time will increase proportionally with number of packages
- Individual package installation failures could impact overall setup experience

## Implementation Notes

### Current Package Locations
```
/package.json                           (root)
/apis/product-api/package.json         (API)
/apis/user-api/package.json            (API)  
/libs/grpc-client-generator/package.json (library)
/services/example-service/package.json   (service)
```

### Suggested Installation Order
1. Root dependencies
2. Library packages (`libs/*`)
3. API packages (`apis/*`)
4. Service packages (`services/*`)