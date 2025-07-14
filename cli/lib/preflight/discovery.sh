#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT DISCOVERY MODULE
# =============================================================================
# This module handles package discovery and verification script detection
# for the preflight command.

# =============================================================================
# PACKAGE DISCOVERY
# =============================================================================

# _discover_verification_packages
# Discovers all packages with verify scripts in the repository
# Returns array of package directories
_discover_verification_packages() {
    log_info "🔍 Discovering packages with verify scripts..." >&2
    
    local packages_with_verify=()
    while IFS= read -r -d '' pkg_json; do
        if jq -e '.scripts.verify' "$pkg_json" > /dev/null 2>&1; then
            local package_dir
            package_dir=$(dirname "$pkg_json")
            packages_with_verify+=("$package_dir")
        fi
    done < <(find "$REPO_ROOT" -mindepth 2 -type f -name "package.json" -not -path "*/node_modules/*" -print0)
    
    if [[ ${#packages_with_verify[@]} -eq 0 ]]; then
        log_warning "No packages with verify scripts found" >&2
        exit 0
    fi
    
    printf '%s\n' "${packages_with_verify[@]}"
}