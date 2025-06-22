#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# SETUP OPERATIONS MODULE - LOADER
# =============================================================================
# This module loads all setup operations for the Lab CLI including
# tool installation, environment validation, and service configuration.

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Module loading function with error handling
source_setup_module() {
    local module="$1"
    local module_path="$(dirname "${BASH_SOURCE[0]}")/setup/$module"
    if [[ -f "$module_path" ]]; then
        source "$module_path" || {
            echo "Error: Failed to load setup module $module" >&2
            exit 1
        }
    else
        echo "Error: Setup module $module not found at $module_path" >&2
        exit 1
    fi
}

# Load setup modules in dependency order
source_setup_module "validation.sh"     # Environment and tool validation
source_setup_module "os-install.sh"     # OS-specific installation logic
source_setup_module "infrastructure.sh" # Docker/service setup operations
source_setup_module "orchestration.sh"  # Main setup workflow and summary