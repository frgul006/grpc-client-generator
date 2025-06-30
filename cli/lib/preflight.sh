#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT MODULE
# =============================================================================
# This module contains the preflight command implementation for parallel
# package verification across the monorepo.

# =============================================================================
# MODULE IMPORTS
# =============================================================================

# Get the directory of this script
PREFLIGHT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source preflight modules
source "${PREFLIGHT_DIR}/preflight/output-mode.sh"
source "${PREFLIGHT_DIR}/preflight/phase-tracker.sh"
source "${PREFLIGHT_DIR}/preflight/dashboard.sh"

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

# Main preflight command handler with staged execution
handle_preflight_command() {
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
    
    # Create temporary working directory
    local temp_dir
    temp_dir=$(mktemp -d)
    local results_dir="${temp_dir}/results"
    local log_dir="${temp_dir}/logs"
    local status_dir="${temp_dir}/status"
    local live_log="${temp_dir}/live.log"  # Define central log
    mkdir -p "$results_dir" "$log_dir" "$status_dir"
    touch "$live_log"  # Create the file for tailing
    echo "Starting preflight verification..." > "$live_log"  # Initial content
    sync  # Ensure file is flushed to disk
    
    # Set up output mode (dashboard vs verbose) based on TTY detection and flags
    _setup_output_mode "$temp_dir"
    
    tail_pid=""  # Global variable for trap access
    dashboard_pid=""  # Global variable for trap access
    
    # Ensure cleanup on exit
    trap '_cleanup_preflight' EXIT
    
    # Set up live streaming output display
    echo
    echo "========================================"
    echo
    
    # Check for unbuffering tools and warn if none available
    if ! command -v stdbuf &>/dev/null && ! command -v gstdbuf &>/dev/null; then
        log_warning "For optimal live log performance, consider installing coreutils: brew install coreutils"
    fi
    
    # Don't start monitoring until we have packages to show
    # This will be started after package discovery
    
    # Discover packages with verify scripts
    log_info "🔍 Discovering packages with verify scripts..."
    
    local packages_with_verify=()
    while IFS= read -r -d '' pkg_json; do
        if jq -e '.scripts.verify' "$pkg_json" > /dev/null 2>&1; then
            local package_dir
            package_dir=$(dirname "$pkg_json")
            packages_with_verify+=("$package_dir")
        fi
    done < <(find "$REPO_ROOT" -type f -name "package.json" -not -path "*/node_modules/*" -print0)
    
    if [[ ${#packages_with_verify[@]} -eq 0 ]]; then
        log_warning "No packages with verify scripts found"
        return 0
    fi
        
    # Staged execution to handle dependencies - dynamic discovery
    local producers=()
    local consumers=()
    local producer_failed=false
    
    log_info "📦 Found ${#packages_with_verify[@]} packages, staging for execution..."
    for pkg_dir in "${packages_with_verify[@]}"; do
        if jq -e '.lab.role == "producer"' "${pkg_dir}/package.json" > /dev/null 2>&1; then
            producers+=("$pkg_dir")
        else
            consumers+=("$pkg_dir")
        fi
    done
    
    # Now start monitoring with packages discovered
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        # Save package lists to files for dashboard monitor to use
        printf '%s\n' "${producers[@]}" > "${temp_dir}/producers.list"
        printf '%s\n' "${consumers[@]}" > "${temp_dir}/consumers.list"
        
        # Dashboard mode: start background dashboard renderer
        _start_dashboard_monitor "$temp_dir" &
        dashboard_pid=$!
    else
        # Traditional mode: start streaming the last 20 lines of the live log
        tail -n 20 -f "$live_log" &
        tail_pid=$!
        sleep 0.5  # Give tail time to start monitoring the file
    fi
    
    # Stage 1: Run producer packages sequentially
    if [[ "${DASHBOARD_MODE:-false}" != "true" ]]; then
        log_info "📦 Stage 1: Verifying ${#producers[@]} core producer packages..."
    fi
    
    for pkg in "${producers[@]}"; do
        if [[ "${DASHBOARD_MODE:-false}" != "true" ]]; then
            log_info "🔧 Verifying producer: $(basename "$pkg")"
        fi
        # Disable strict error handling for verification (may fail)
        set +e
        _run_single_verify "$pkg" "$temp_dir" "$live_log"
        # Re-enable strict error handling
        set -e
        if [[ -f "${results_dir}/$(basename "$pkg").failure" ]]; then
            producer_failed=true
            break
        fi
    done
    
    # Stage 2: Run consumer packages in parallel (if producers succeeded)
    if [[ "$producer_failed" == true ]]; then
        if [[ "${DASHBOARD_MODE:-false}" != "true" ]]; then
            log_error "⚠️  Core producer package failed verification. Halting parallel execution."
        fi
    elif [[ ${#consumers[@]} -gt 0 ]]; then
        local cpu_cores
        cpu_cores=$(get_cpu_cores)
        if [[ "${DASHBOARD_MODE:-false}" != "true" ]]; then
            log_info "⚡ Stage 2: Verifying ${#consumers[@]} consumer packages in parallel (${cpu_cores} cores)"
        fi
        
        # Export variables for parallel execution
        export DASHBOARD_MODE
        
        # Disable strict error handling for parallel execution (packages may fail)
        set +e
        printf '%s\n' "${consumers[@]}" | \
            xargs -P "$cpu_cores" -I {} bash -c '_run_single_verify "$@"' _ {} "$temp_dir" "$live_log"
        # Re-enable strict error handling
        set -e
    fi
    
    # Final status sync for dashboard mode - ensure all completions are recorded
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        # Wait a moment for any pending status updates
        sleep 0.5
        
        # Force update any packages that completed but may not have updated status
        for result_file in "$results_dir"/*.success; do
            [[ -e "$result_file" ]] || continue
            local package_name=$(basename "$result_file" .success)
            _update_package_status "$package_name" "$temp_dir" "completed"
        done
        
        for result_file in "$results_dir"/*.failure; do
            [[ -e "$result_file" ]] || continue
            local package_name=$(basename "$result_file" .failure)
            _update_package_status "$package_name" "$temp_dir" "failed"
        done
        
        # Give dashboard one final update, then stop it before summary
        sleep 0.2
        
        # Stop dashboard monitor before showing summary
        if [[ -n "${dashboard_pid:-}" ]]; then
            { kill "$dashboard_pid" && wait "$dashboard_pid"; } 2>/dev/null || true
            dashboard_pid=""  # Clear the PID so cleanup doesn't try again
            
            # Move cursor below dashboard area and show cursor
            if [[ -t 1 ]]; then
                printf "\n\n"  # Add some space after dashboard
                tput cnorm 2>/dev/null || printf "\033[?25h"  # Show cursor
            fi
        fi
    fi
    
    # Aggregate and report results
    local overall_status=0
    local success_count=0
    local failure_count=0
    
    if [[ "${DASHBOARD_MODE:-false}" != "true" ]]; then
        echo
        log_info "📊 PREFLIGHT SUMMARY"
    fi
    echo "================================"
    
    # Report successes
    for result_file in "$results_dir"/*.success; do
        [[ -e "$result_file" ]] || continue
        local package_name
        package_name=$(basename "$result_file" .success)
        echo "✅ SUCCESS: ${package_name}"
        success_count=$((success_count + 1))
    done
    
    # Report failures with logs
    for result_file in "$results_dir"/*.failure; do
        [[ -e "$result_file" ]] || continue
        overall_status=1
        local package_name
        package_name=$(basename "$result_file" .failure)
        local exit_code
        exit_code=$(cat "$result_file")
        echo "❌ FAILURE: ${package_name} (Exit: $exit_code)"
        
        # Show failure log
        local log_file="${log_dir}/${package_name}.log"
        if [[ -f "$log_file" ]]; then
            echo "--- Log for ${package_name} ---"
            cat "$log_file"
            echo "--------------------------------"
        fi
        failure_count=$((failure_count + 1))
    done
    
    echo
    echo "📈 Results: ${success_count} passed, ${failure_count} failed"
    
    # If tail is running, stop it before showing final results
    if [[ -n "$tail_pid" ]]; then
        { kill "$tail_pid" && wait "$tail_pid"; } 2>/dev/null || true
        tail_pid=""
        echo
        echo "========================================"
        echo
    fi
    
    if [[ $overall_status -eq 0 ]]; then
        log_success "All preflight checks passed! ✅"
        exit 0
    else
        log_error "Preflight checks failed ❌"
        exit 1
    fi
}