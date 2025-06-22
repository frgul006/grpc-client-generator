#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# STATE MANAGEMENT AND ERROR RECOVERY MODULE - LOADER
# =============================================================================
# This module loads setup state persistence, checkpointing, error recovery,
# and retry mechanisms for the Lab CLI tool.

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Module loading function with error handling
source_state_module() {
    local module="$1"
    local module_path="$(dirname "${BASH_SOURCE[0]}")/state/$module"
    if [[ -f "$module_path" ]]; then
        source "$module_path" || {
            echo "Error: Failed to load state module $module" >&2
            exit 1
        }
    else
        echo "Error: State module $module not found at $module_path" >&2
        exit 1
    fi
}

# Load state modules in dependency order
source_state_module "persistence.sh"  # State file management and checkpointing
source_state_module "execution.sh"    # Error handling, retry mechanisms, step execution