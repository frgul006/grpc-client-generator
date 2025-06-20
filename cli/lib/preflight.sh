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
    local package_name=$(basename "$package_dir")
    local temp_dir="$2"
    local log_file="${temp_dir}/logs/${package_name}.log"
    local results_dir="${temp_dir}/results"
    
    # Change to directory and run verify, capturing all output
    (cd "$package_dir" && npm run verify) > "$log_file" 2>&1
    local exit_code=$?  # Capture exit code IMMEDIATELY after command
    
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
    mkdir -p "$results_dir" "$log_dir"
    
    # Ensure cleanup on exit
    trap "rm -rf \"$temp_dir\"" EXIT
    
    
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
    
    log_info "📦 Found ${#packages_with_verify[@]} packages with verify scripts"
    
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
        _run_single_verify "$pkg" "$temp_dir"
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
            xargs -P "$cpu_cores" -I {} bash -c '_run_single_verify "$@"' _ {} "$temp_dir"
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
    
    if [[ $overall_status -eq 0 ]]; then
        log_success "All preflight checks passed! ✅"
        exit 0
    else
        log_error "Preflight checks failed ❌"
        exit 1
    fi
}