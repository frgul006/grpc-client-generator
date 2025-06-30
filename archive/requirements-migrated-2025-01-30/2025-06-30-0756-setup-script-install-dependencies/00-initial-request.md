# Initial Request

## Ticket: Install Dependencies Across All Packages

### What
Enhance the `lab setup` command to install dependencies across all package.json files in the monorepo, not just the product-api package. Currently, the setup only installs dependencies for `apis/product-api`, leaving other packages without their required dependencies.

### Why
- **Complete Environment Setup**: All packages need their dependencies installed for the development environment to function properly
- **Monorepo Support**: The repository contains multiple packages (APIs, libraries, services) that each have their own dependencies
- **Developer Experience**: Developers expect `lab setup` to fully prepare their environment for all project components
- **Build Pipeline**: Other packages (like `libs/grpc-client-generator`) may be dependencies for the APIs and services
- **Consistency**: Setup should handle all packages uniformly rather than hardcoding specific paths

The current implementation in `cli/lib/setup/infrastructure.sh:68-99` only handles the product-api directory, leaving developers to manually install dependencies for other packages.

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