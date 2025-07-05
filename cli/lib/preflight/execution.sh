#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT EXECUTION MODULE
# =============================================================================
# This module handles sequential producer execution and parallel consumer
# execution for the preflight command.

# =============================================================================
# EXECUTION COORDINATION
# =============================================================================

# _execute_staged_verification
# Executes producer packages sequentially, then consumer packages in parallel
# Args: temp_dir
_execute_staged_verification() {
    local temp_dir="$1"
    local results_dir="${temp_dir}/results"
    local live_log="${temp_dir}/live.log"
    
    # Read package arrays from files
    local producers=()
    local consumers=()
    
    if [[ -f "${temp_dir}/producers.list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && producers+=("$line")
        done < "${temp_dir}/producers.list"
    fi
    
    if [[ -f "${temp_dir}/consumers.list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && consumers+=("$line")
        done < "${temp_dir}/consumers.list"
    fi
    local producer_failed=false
    
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
}