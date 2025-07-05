#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT AGGREGATION MODULE
# =============================================================================
# This module handles results collection, summary reporting, and final
# cleanup for the preflight command.

# =============================================================================
# RESULTS AGGREGATION
# =============================================================================

# _aggregate_verification_results
# Collects and reports verification results, handles final cleanup
# Args: temp_dir
_aggregate_verification_results() {
    local temp_dir="$1"
    local results_dir="${temp_dir}/results"
    local log_dir="${temp_dir}/logs"
    
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
    if [[ -n "${tail_pid:-}" ]]; then
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