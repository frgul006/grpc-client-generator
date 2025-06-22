#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# COMMAND HANDLERS MODULE - LOADER
# =============================================================================
# This module loads command parsing, dispatch logic, and individual
# command handler functions for the Lab CLI.

# Module loading function with error handling
source_command_module() {
    local module="$1"
    local module_path="$(dirname "${BASH_SOURCE[0]}")/commands/$module"
    if [[ -f "$module_path" ]]; then
        source "$module_path" || {
            echo "Error: Failed to load command module $module" >&2
            exit 1
        }
    else
        echo "Error: Command module $module not found at $module_path" >&2
        exit 1
    fi
}

# Load command modules in dependency order
source_command_module "parser.sh"      # Argument parsing and validation
source_command_module "dispatcher.sh"  # Command routing logic
source_command_module "handlers.sh"    # Individual command implementations