#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT WORKSPACE MODULE
# =============================================================================
# This module handles temporary directory creation, output mode configuration,
# and cleanup setup for the preflight command.

# =============================================================================
# WORKSPACE SETUP
# =============================================================================

# _setup_preflight_workspace
# Creates temporary working directory structure and sets up output mode
# Sets global temp_dir variable
_setup_preflight_workspace() {
    # Create temporary working directory
    temp_dir=$(mktemp -d)
    local results_dir="${temp_dir}/results"
    local log_dir="${temp_dir}/logs"
    local status_dir="${temp_dir}/status"
    local live_log="${temp_dir}/live.log"
    mkdir -p "$results_dir" "$log_dir" "$status_dir"
    touch "$live_log"
    echo "Starting preflight verification..." > "$live_log"
    sync  # Ensure file is flushed to disk
    
    # Set up output mode (dashboard vs verbose) based on TTY detection and flags
    _setup_output_mode "$temp_dir"
    
    # Initialize global variables for cleanup
    tail_pid=""
    dashboard_pid=""
    
    # Ensure cleanup on exit
    trap '_cleanup_preflight' EXIT
    
    # Set up live streaming output display
    echo >&2
    echo "========================================" >&2
    echo >&2
    
    # Check for unbuffering tools and warn if none available
    if ! command -v stdbuf &>/dev/null && ! command -v gstdbuf &>/dev/null; then
        log_warning "For optimal live log performance, consider installing coreutils: brew install coreutils"
    fi
}