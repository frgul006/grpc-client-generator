#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT STAGING MODULE
# =============================================================================
# This module handles package staging into producers/consumers and sets up
# monitoring for the preflight command.

# =============================================================================
# PACKAGE STAGING
# =============================================================================

# _stage_packages_by_role
# Classifies packages into producers and consumers, sets up monitoring
# Args: temp_dir packages_array
_stage_packages_by_role() {
    local temp_dir="$1"
    shift
    local packages_with_verify=("$@")
    
    # Staged execution to handle dependencies - dynamic discovery
    local producers=()
    local consumers=()
    
    log_info "📦 Found ${#packages_with_verify[@]} packages, staging for execution..."
    for pkg_dir in "${packages_with_verify[@]}"; do
        if jq -e '.lab.role == "producer"' "${pkg_dir}/package.json" > /dev/null 2>&1; then
            producers+=("$pkg_dir")
        else
            consumers+=("$pkg_dir")
        fi
    done
    
    # Save package lists to files for both dashboard and execution modules
    printf '%s\n' "${producers[@]}" > "${temp_dir}/producers.list"
    printf '%s\n' "${consumers[@]}" > "${temp_dir}/consumers.list"
    
    # Start monitoring with packages discovered
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        # Dashboard mode: start background dashboard renderer
        _start_dashboard_monitor "$temp_dir" &
        dashboard_pid=$!
    else
        # Traditional mode: start streaming the last 20 lines of the live log
        tail -n 20 -f "${temp_dir}/live.log" &
        tail_pid=$!
        sleep 0.5  # Give tail time to start monitoring the file
    fi
}