#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT MODULE
# =============================================================================
# This module contains the preflight command implementation for parallel
# package verification across the monorepo.

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# _cleanup_preflight
# This function is registered with 'trap EXIT' to ensure proper cleanup
# of background processes (like the tail viewer) and temporary files
# when the script exits, regardless of success or failure.
_cleanup_preflight() {
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
    
    
    # Run verify, teeing raw output to package log, then prefix for live log
    # The subshell captures both stdout and stderr
    # Use stdbuf if available to force unbuffered output for real-time display
    
    if command -v stdbuf &>/dev/null; then
        (cd "$package_dir" && npm run verify) 2>&1 | \
            stdbuf -o0 tee "$log_file" | \
            stdbuf -o0 awk -v pkg="[$package_name]" '{print pkg, $0; fflush()}' >> "$live_log_path"
    elif command -v gstdbuf &>/dev/null; then
        # macOS with Homebrew coreutils
        (cd "$package_dir" && npm run verify) 2>&1 | \
            gstdbuf -o0 tee "$log_file" | \
            gstdbuf -o0 awk -v pkg="[$package_name]" '{print pkg, $0; fflush()}' >> "$live_log_path"
    else
        # Fallback: use sed with platform-specific unbuffered flag
        local sed_unbuf_flag="-u"
        if ! sed --version 2>&1 | grep -q GNU; then
            sed_unbuf_flag="-l"  # BSD/macOS sed
        fi
        (cd "$package_dir" && npm run verify) 2>&1 | \
            tee "$log_file" | \
            sed $sed_unbuf_flag "s/^/[$package_name] /" >> "$live_log_path"
    fi
    
    local exit_code=${PIPESTATUS[0]}  # Capture exit code of 'npm run verify', not tee or awk
    
    if [[ $exit_code -eq 0 ]]; then
        # Success: create success marker and clean log
        touch "${results_dir}/${package_name}.success"
        rm -f "$log_file"
        # No echo output - summary handled by main function
    else
        # Failure: create failure marker with exit code
        echo "$exit_code" > "${results_dir}/${package_name}.failure"
        # No echo output - summary handled by main function
    fi
    

}

# Export function for xargs subshells
export -f _run_single_verify

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
    local live_log="${temp_dir}/live.log"  # Define central log
    mkdir -p "$results_dir" "$log_dir"
    touch "$live_log"  # Create the file for tailing
    echo "Starting preflight verification..." > "$live_log"  # Initial content
    sync  # Ensure file is flushed to disk
    
    tail_pid=""  # Global variable for trap access
    
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
    
    # Start streaming the last 20 lines of the live log
    tail -n 20 -f "$live_log" &
    tail_pid=$!
    sleep 0.5  # Give tail time to start monitoring the file
    
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
    
    # Stage 1: Run producer packages sequentially
    log_info "📦 Stage 1: Verifying ${#producers[@]} core producer packages..."
    
    
    for pkg in "${producers[@]}"; do
        log_info "🔧 Verifying producer: $(basename "$pkg")"
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
        log_error "⚠️  Core producer package failed verification. Halting parallel execution."
    elif [[ ${#consumers[@]} -gt 0 ]]; then
        local cpu_cores
        cpu_cores=$(get_cpu_cores)
        log_info "⚡ Stage 2: Verifying ${#consumers[@]} consumer packages in parallel (${cpu_cores} cores)"
        
        
        # Disable strict error handling for parallel execution (packages may fail)
        set +e
        printf '%s
' "${consumers[@]}" | \
            xargs -P "$cpu_cores" -I {} bash -c '_run_single_verify "$@"' _ {} "$temp_dir" "$live_log"
        # Re-enable strict error handling
        set -e
    fi
    
    # Aggregate and report results
    local overall_status=0
    local success_count=0
    local failure_count=0
    
    echo
    log_info "📊 PREFLIGHT SUMMARY"
    echo "================================"
    
    # Report successes
    for result_file in "$results_dir"/*.success; do
        [[ -e "$result_file" ]] || continue
        local package_name
        package_name=$(basename "$result_file" .success)
        echo "✅ SUCCESS: ${package_name}"
        ((success_count++))
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
        ((failure_count++))
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