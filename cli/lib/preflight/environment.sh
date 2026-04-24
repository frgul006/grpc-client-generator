#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT ENVIRONMENT MODULE
# =============================================================================
# This module handles environment validation and dependency checks for the
# preflight command.

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

# _validate_preflight_environment
# Validates that all required environment variables and dependencies are
# available for preflight execution
_validate_preflight_environment() {
    # Validate REPO_ROOT is set and valid
    if [[ -z "$REPO_ROOT" || ! -d "$REPO_ROOT" ]]; then
        log_error "REPO_ROOT is not defined or is not a valid directory"
        exit 1
    fi
    
    log_info "🚀 Running preflight verification across all packages..."
    
    # Dependency checks
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for preflight command but not installed"
        log_info "💡 Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi
    
    if ! command -v npm &>/dev/null; then
        log_error "npm is required for preflight command but not installed"
        exit 1
    fi
}