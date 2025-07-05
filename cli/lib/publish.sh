#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PUBLISH MODULE
# =============================================================================
# This module handles publishing packages to the local Verdaccio registry
# with automatic version management and dependency updates

# =============================================================================
# PUBLISH HELPERS
# =============================================================================

# Generate a unique dev version tag
generate_dev_version() {
    echo "0.0.0-dev.$(date +%s)"
}

# Save current package.json version
save_package_version() {
    local package_path="$1"
    local package_json="$package_path/package.json"
    
    if [[ ! -f "$package_json" ]]; then
        log_error "package.json not found at $package_path"
        return 1
    fi
    
    # Extract current version
    local current_version
    current_version=$(node -p "require('$package_json').version" 2>/dev/null || echo "")
    
    if [[ -z "$current_version" ]]; then
        log_error "Failed to read version from package.json"
        return 1
    fi
    
    echo "$current_version"
}

# Restore package.json version
restore_package_version() {
    local package_path="$1"
    local original_version="$2"
    local package_json="$package_path/package.json"
    
    if [[ ! -f "$package_json" ]]; then
        log_error "package.json not found at $package_path"
        return 1
    fi
    
    # Use npm version to restore, with --no-git-tag-version to avoid git operations
    (cd "$package_path" && npm version "$original_version" --no-git-tag-version --allow-same-version &>/dev/null)
}

# Find all packages that depend on the given package
find_dependent_packages() {
    local package_name="$1"
    local dependencies=()
    
    # Find all package.json files (excluding node_modules)
    while IFS= read -r -d '' package_json; do
        # Check if this package has our target package as a dependency
        if node -p "
            const pkg = require('$package_json');
            const deps = Object.assign({}, pkg.dependencies || {}, pkg.devDependencies || {});
            deps['$package_name'] ? 'true' : 'false'
        " 2>/dev/null | grep -q "true"; then
            dependencies+=("$(dirname "$package_json")")
        fi
    done < <(find "$REPO_ROOT" -name "package.json" -not -path "*/node_modules/*" -print0)
    
    printf '%s\n' "${dependencies[@]}"
}

# Update a package dependency
update_package_dependency() {
    local package_path="$1"
    local dependency_name="$2"
    local dev_version="$3"

    log_debug "Updating $dependency_name in $package_path"
    
    # Save current directory
    local current_dir
    current_dir=$(pwd)
    
    # Change to package directory and run update
    cd "$package_path"
    
    # Force install from registry (not workspace) by replacing dependency in one operation
    # This is necessary because npm workspaces with wildcard dependencies prefer symlinks
    log_debug "Replacing workspace dependency with registry version for $dependency_name"
    
    npm install "$dependency_name@$dev_version" --registry="$VERDACCIO_URL" &>/dev/null || true
    
    # Return to original directory
    cd "$current_dir"
}

# =============================================================================
# MAIN PUBLISH COMMAND
# =============================================================================

# Publish a package to the local registry
publish_package() {
    local package_arg="${1:-}"
    
    # Validate package argument
    if [[ -z "$package_arg" ]]; then
        log_error "Package name or path required"
        log_info "Usage: lab publish <package-name|path>"
        log_info "Examples:"
        log_info "  lab publish grpc-client-generator"
        log_info "  lab publish ./libs/grpc-client-generator"
        return 1
    fi
    
    # Determine package path
    local package_path=""
    local package_name=""
    
    if [[ -d "$package_arg" ]]; then
        # Path provided
        package_path="$(cd "$package_arg" && pwd)"
        if [[ -f "$package_path/package.json" ]]; then
            package_name=$(node -p "require('$package_path/package.json').name" 2>/dev/null || echo "")
        else
            log_error "No package.json found in $package_arg"
            return 1
        fi
    else
        # Package name provided - search for it
        package_name="$package_arg"
        
        # Search in common locations
        for search_dir in "$REPO_ROOT/libs" "$REPO_ROOT/apis" "$REPO_ROOT/services"; do
            if [[ -d "$search_dir/$package_name" && -f "$search_dir/$package_name/package.json" ]]; then
                package_path="$search_dir/$package_name"
                break
            fi
        done
        
        # If not found, search everywhere
        if [[ -z "$package_path" ]]; then
            while IFS= read -r -d '' found_package; do
                local found_name
                found_name=$(node -p "require('$found_package').name" 2>/dev/null || echo "")
                if [[ "$found_name" == "$package_name" ]]; then
                    package_path="$(dirname "$found_package")"
                    break
                fi
            done < <(find "$REPO_ROOT" -name "package.json" -not -path "*/node_modules/*" -print0)
        fi
        
        if [[ -z "$package_path" ]]; then
            log_error "Package '$package_name' not found in repository"
            return 1
        fi
    fi
    
    log_info "Publishing package: $package_name"
    log_info "Path: $package_path"
    
    # Check if Verdaccio is running
    if ! check_verdaccio_running; then
        log_error "Verdaccio is not running. Run 'lab setup' first."
        return 1
    fi
    
    # Save current version
    local original_version
    original_version=$(save_package_version "$package_path")
    if [[ -z "$original_version" ]]; then
        return 1
    fi
    
    log_info "Current version: $original_version"
    
    # Generate and set dev version
    local dev_version
    dev_version=$(generate_dev_version)
    log_info "Temporary dev version: $dev_version"
    
    # Change to package directory for all operations
    cd "$package_path"
    
    # Update to dev version
    if ! npm version "$dev_version" --no-git-tag-version &>/dev/null; then
        log_error "Failed to set dev version"
        return 1
    fi
    
    # Build the package if build script exists
    if npm run --silent 2>/dev/null | grep -q "^  build$"; then
        log_info "Building package..."
        if ! npm run build; then
            log_error "Build failed"
            restore_package_version "$package_path" "$original_version"
            return 1
        fi
    fi
    
    # Publish to local registry
    log_info "Publishing to local registry..."
    if ! npm publish --registry="$VERDACCIO_URL" --tag dev --force; then
        log_error "Failed to publish to local registry"
        restore_package_version "$package_path" "$original_version"
        return 1
    fi
    
    log_success "Published $package_name@$dev_version to local registry"
    
    # Restore original version
    restore_package_version "$package_path" "$original_version"
    log_info "Restored version to $original_version"
    
    # Find and update dependent packages
    log_info "Searching for dependent packages..."
    local dependent_packages=()
    while IFS= read -r dep; do
        dependent_packages+=("$dep")
    done < <(find_dependent_packages "$package_name")
    
    if [[ ${#dependent_packages[@]} -eq 0 ]]; then
        log_info "No dependent packages found"
    else
        log_info "Found ${#dependent_packages[@]} dependent package(s)"
        
        for dep_path in "${dependent_packages[@]}"; do
            local dep_name
            dep_name=$(basename "$dep_path")
            log_info "Updating $dep_name..."
            
            if update_package_dependency "$dep_path" "$package_name" "$dev_version"; then
                log_success "Updated $dep_name"
            else
                log_warning "Failed to update $dep_name"
            fi
        done
    fi
    
    log_success "Package publish completed!"
    log_info "The package is available at $VERDACCIO_URL"
}