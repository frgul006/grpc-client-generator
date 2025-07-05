#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT MODULE - MAIN ORCHESTRATOR
# =============================================================================
# This module contains the refactored preflight command implementation for
# parallel package verification across the monorepo.

# =============================================================================
# MODULE IMPORTS
# =============================================================================

# Get the directory of this script
PREFLIGHT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source preflight modules in dependency order
source "${PREFLIGHT_DIR}/output-mode.sh"
source "${PREFLIGHT_DIR}/phase-tracker.sh"
source "${PREFLIGHT_DIR}/dashboard.sh"
source "${PREFLIGHT_DIR}/environment.sh"
source "${PREFLIGHT_DIR}/workspace.sh"
source "${PREFLIGHT_DIR}/discovery.sh"
source "${PREFLIGHT_DIR}/staging.sh"
source "${PREFLIGHT_DIR}/execution.sh"
source "${PREFLIGHT_DIR}/aggregation.sh"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# _cleanup_preflight
# This function is registered with 'trap EXIT' to ensure proper cleanup
# of background processes (like the tail viewer) and temporary files
# when the script exits, regardless of success or failure.
_cleanup_preflight() {
    # Clean up dashboard-specific resources first
    _cleanup_dashboard
    
    # Clean up background monitoring processes
    if [[ -n "${dashboard_pid:-}" ]]; then
        # Kill the dashboard process and wait for it to exit cleanly
        { kill "$dashboard_pid" && wait "$dashboard_pid"; } 2>/dev/null || true
        sleep 0.1  # Small delay for visual stability
        
        # Just show cursor, don't clear the final summary
        if [[ "${DASHBOARD_MODE:-false}" == "true" && -t 1 ]]; then
            tput cnorm 2>/dev/null || printf "\033[?25h"  # Show cursor
        fi
    fi
    
    if [[ -n "${tail_pid:-}" ]]; then
        # Kill the tail process and wait for it to exit cleanly
        { kill "$tail_pid" && wait "$tail_pid"; } 2>/dev/null || true
        sleep 0.1  # Small delay for visual stability
    fi
    tput cnorm  # Restore cursor
    if [[ -n "${temp_dir:-}" ]]; then
        rm -rf "$temp_dir"
    fi
}

# Cross-platform CPU core detection
get_cpu_cores() {
    # Most portable method across Linux and macOS
    if command -v getconf &>/dev/null; then
        getconf _NPROCESSORS_ONLN 2>/dev/null || echo "2"
    else
        # Fallback methods
        if command -v nproc &>/dev/null; then
            nproc
        elif command -v sysctl &>/dev/null; then
            sysctl -n hw.ncpu 2>/dev/null || echo "2"
        else
            echo "2"  # Conservative default to prevent resource exhaustion
        fi
    fi
}

# Single package verification function for parallel execution
_run_single_verify() {
    local package_dir=$1
    local temp_dir="$2"
    local live_log_path="$3"  # Passed from parent
    local package_name=$(basename "$package_dir")
    local log_file="${temp_dir}/logs/${package_name}.log"
    local results_dir="${temp_dir}/results"
    
    # Initialize package status if in dashboard mode
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        _init_package_status "$package_name" "$temp_dir"
    fi
    
    # Run verify with different output handling based on mode
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        # Dashboard mode: no live log, just save to file and track phases
        if command -v stdbuf &>/dev/null; then
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                stdbuf -o0 tee "$log_file" >/dev/null
        elif command -v gstdbuf &>/dev/null; then
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                gstdbuf -o0 tee "$log_file" >/dev/null
        else
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                tee "$log_file" >/dev/null
        fi
    else
        # Verbose mode: use live log as before
        if command -v stdbuf &>/dev/null; then
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                stdbuf -o0 tee "$log_file" | \
                stdbuf -o0 awk -v pkg="[$package_name]" '{print pkg, $0; fflush()}' >> "$live_log_path"
        elif command -v gstdbuf &>/dev/null; then
            # macOS with Homebrew coreutils
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                gstdbuf -o0 tee "$log_file" | \
                gstdbuf -o0 awk -v pkg="[$package_name]" '{print pkg, $0; fflush()}' >> "$live_log_path"
        else
            # Fallback: use sed with platform-specific unbuffered flag
            local sed_unbuf_flag="-u"
            if ! sed --version 2>&1 | grep -q GNU; then
                sed_unbuf_flag="-l"  # BSD/macOS sed
            fi
            (cd "$package_dir" && npm run verify) 2>&1 | \
                _process_verify_output "$package_name" "$temp_dir" | \
                tee "$log_file" | \
                sed $sed_unbuf_flag "s/^/[$package_name] /" >> "$live_log_path"
        fi
    fi
    
    local exit_code=${PIPESTATUS[0]}  # Capture exit code of 'npm run verify', not tee or awk
    
    if [[ $exit_code -eq 0 ]]; then
        # Success: mark as completed first, then create marker
        if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
            _update_package_status "$package_name" "$temp_dir" "completed"
        fi
        touch "${results_dir}/${package_name}.success"
        rm -f "$log_file"
    else
        # Failure: mark as failed first, then create marker
        if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
            _update_package_status "$package_name" "$temp_dir" "failed"
        fi
        echo "$exit_code" > "${results_dir}/${package_name}.failure"
    fi
}

# Export functions and variables for xargs subshells
export -f _run_single_verify
export -f _process_verify_output
export -f _parse_npm_phase
export -f _update_package_status
export -f _init_package_status
export -f _calculate_phase_timing
export DASHBOARD_MODE

# =============================================================================
# MAIN PREFLIGHT COMMAND HANDLER
# =============================================================================

# Main preflight command handler with modular architecture
handle_preflight_command() {
    _validate_preflight_environment
    _setup_preflight_workspace
    
    # Discover packages
    local packages_output
    packages_output=$(_discover_verification_packages)
    local packages=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && packages+=("$line")
    done <<< "$packages_output"
    
    # Stage packages and get producers/consumers
    _stage_packages_by_role "$temp_dir" "${packages[@]}"
    
    # Execute verification
    _execute_staged_verification "$temp_dir"
    
    # Aggregate results
    _aggregate_verification_results "$temp_dir"
}