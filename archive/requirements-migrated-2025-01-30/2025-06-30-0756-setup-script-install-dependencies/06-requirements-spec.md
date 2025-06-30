# Requirements Specification: Install Dependencies Across All Packages

## Problem Statement

The current `lab setup` command only installs dependencies for the `apis/product-api` package, leaving other packages in the monorepo without their required dependencies. This forces developers to manually install dependencies for each package, creating an incomplete development environment setup.

## Solution Overview

Enhance the `install_dependencies()` function in `cli/lib/setup/infrastructure.sh` to dynamically discover and install dependencies for all packages in the monorepo, maintaining the existing Verdaccio registry configuration and retry logic while providing real-time progress feedback.

## Functional Requirements

### 1. Package Discovery
- **FR1.1**: Discover all directories containing `package.json` files within the repository
- **FR1.2**: Include packages from root directory and subdirectories: `/apis/*`, `/libs/*`, `/services/*`
- **FR1.3**: Exclude `node_modules` and `registry` directories from discovery
- **FR1.4**: Skip directories that don't contain a `package.json` file

### 2. Installation Process
- **FR2.1**: Install dependencies sequentially (not in parallel)
- **FR2.2**: Continue with remaining packages if one fails (no early termination)
- **FR2.3**: Display real-time progress showing which package is currently being installed
- **FR2.4**: Maintain installation order: root → libraries → APIs → services

### 3. Registry Management
- **FR3.1**: Configure npm to use Verdaccio registry before each package installation
- **FR3.2**: Reset npm registry to default after each package installation
- **FR3.3**: Use existing retry logic with exponential backoff for each installation

### 4. Error Handling
- **FR4.1**: Track failed installations and continue with remaining packages
- **FR4.2**: Report all failures at the end with clear indication of which packages failed
- **FR4.3**: Return success if at least one package was installed successfully

### 5. Progress Reporting
- **FR5.1**: Use existing logging functions (log_info, log_success, log_error)
- **FR5.2**: Show package name and path during installation
- **FR5.3**: Update setup summary to show installation status for all packages

## Technical Requirements

### 1. Code Location
- **TR1.1**: Modify `install_dependencies()` function in `cli/lib/setup/infrastructure.sh`
- **TR1.2**: Update `show_setup_summary()` in `cli/lib/setup/orchestration.sh`

### 2. Implementation Patterns
- **TR2.1**: Follow existing package discovery pattern from `handle_dev_command()`
- **TR2.2**: Use `retry_with_backoff` for each npm install operation
- **TR2.3**: Maintain existing error handling and logging patterns

### 3. State Management
- **TR3.1**: Use single checkpoint for entire dependency installation phase
- **TR3.2**: Don't create individual checkpoints per package (avoiding overengineering)

## Implementation Hints

### Package Discovery Pattern
```bash
# Find all package.json files excluding node_modules and registry
find "$REPO_ROOT" -name "package.json" \
    -not -path "*/node_modules/*" \
    -not -path "*/registry/*" \
    -type f | while read pkg_file; do
    pkg_dir=$(dirname "$pkg_file")
    # Process each package directory
done
```

### Installation Order
1. Process root package.json first
2. Sort remaining packages: libs/* before apis/* before services/*

### Progress Logging Example
```bash
log_info "Installing dependencies for $package_name ($pkg_dir)..."
```

## Acceptance Criteria

1. **AC1**: Running `lab setup` installs dependencies for all 5 packages in the monorepo
2. **AC2**: Installation continues even if individual packages fail
3. **AC3**: Real-time progress shows which package is currently being processed
4. **AC4**: Setup summary displays installation status for each package
5. **AC5**: Failed installations are clearly reported without stopping the entire setup
6. **AC6**: Existing retry logic and Verdaccio registry configuration work for all packages
7. **AC7**: Registry directory is excluded from package discovery
8. **AC8**: npm registry is properly reset after each package installation

## Assumptions

1. All packages use npm (not yarn or other package managers)
2. Verdaccio registry is already running when install_dependencies is called
3. Package installation order (libs before apis/services) is sufficient for dependency resolution
4. No need for parallel installation due to potential dependency conflicts
5. No validation of package.json contents beyond file existence