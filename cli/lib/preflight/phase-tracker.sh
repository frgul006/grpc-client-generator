#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT PHASE TRACKER MODULE
# =============================================================================
# This module handles phase detection, timing, and state management for the
# preflight dashboard display.

# =============================================================================
# PHASE DETECTION AND STATE MANAGEMENT
# =============================================================================

# Parse npm output to detect current phase
# Args: $1 - output line to parse, $2 - package name (for context)
# Returns: detected phase name or "unknown"
_parse_npm_phase() {
    local line="$1"
    local package_name="${2:-}"
    local phase="unknown"
    
    # Only detect main verify script phases by looking for the root package invocation
    # This prevents detection of nested script calls (like e2e -> build)
    if [[ "$line" =~ ^"> $package_name@".*" lint"$ ]]; then
        phase="lint"
    elif [[ "$line" =~ ^"> $package_name@".*" format"$ ]] || [[ "$line" =~ ^"> $package_name@".*" format:check"$ ]]; then
        phase="format"
    elif [[ "$line" =~ ^"> $package_name@".*" build"$ ]]; then
        phase="build"
    elif [[ "$line" =~ ^"> $package_name@".*" test"$ ]] || [[ "$line" =~ ^"> $package_name@".*" test:e2e"$ ]]; then
        phase="test"
    fi
    
    echo "$phase"
}

# Initialize status files for a package
# Args: $1 - package name, $2 - temp directory
_init_package_status() {
    local package_name="$1"
    local temp_dir="$2"
    local status_dir="${temp_dir}/status"
    
    mkdir -p "$status_dir"
    
    # Initialize status files
    echo "pending" > "${status_dir}/${package_name}.phase"
    echo "" > "${status_dir}/${package_name}.start"
    : > "${status_dir}/${package_name}.phases"  # Create empty file without newline
}

# Update package state files with current phase
# Args: $1 - package name, $2 - temp directory, $3 - new phase
_update_package_status() {
    local package_name="$1"
    local temp_dir="$2"
    local new_phase="$3"
    local status_dir="${temp_dir}/status"
    local current_time=$(date +%s.%N)
    
    # Ensure status directory exists
    mkdir -p "$status_dir"
    
    # Get current phase to detect transitions
    local current_phase=""
    if [[ -f "${status_dir}/${package_name}.phase" ]]; then
        current_phase=$(cat "${status_dir}/${package_name}.phase")
    fi
    
    # If phase changed and it's not unknown, handle transition
    if [[ "$new_phase" != "unknown" && "$new_phase" != "$current_phase" ]]; then
        # Implement simple forward progression to prevent duplicates
        # Phase order: pending -> lint -> format -> build -> test -> completed
        local should_update=true
        
        # Get phase priority (higher number = later in sequence)
        get_phase_priority() {
            case "$1" in
                pending) echo 0 ;;
                lint) echo 1 ;;
                format) echo 2 ;;
                build) echo 3 ;;
                test) echo 4 ;;
                completed) echo 5 ;;
                failed) echo 6 ;;
                *) echo 0 ;;
            esac
        }
        
        # Only allow forward progression (prevent going backwards)
        if [[ -n "$current_phase" && "$current_phase" != "pending" ]]; then
            local current_priority=$(get_phase_priority "$current_phase")
            local new_priority=$(get_phase_priority "$new_phase")
            
            # Allow transition only if moving forward or to completed/failed
            if [[ $new_priority -le $current_priority && "$new_phase" != "completed" && "$new_phase" != "failed" ]]; then
                should_update=false
            fi
        fi
        
        if [[ "$should_update" == "true" ]]; then
            # If we had a previous phase, record its completion with timing
            if [[ -n "$current_phase" && "$current_phase" != "pending" ]]; then
                local phase_duration
                phase_duration=$(_calculate_phase_timing "$package_name" "$temp_dir")
                echo "${current_phase}:${phase_duration}" >> "${status_dir}/${package_name}.phases"
            fi
            
            # Update to new phase and record start time
            echo "$new_phase" > "${status_dir}/${package_name}.phase"
            echo "$current_time" > "${status_dir}/${package_name}.start"
            
            # Debug: Write to a debug log to see if this is being called
            echo "$(date): $package_name -> $new_phase" >> "${temp_dir}/debug.log"
        fi
    fi
}

# Calculate phase duration from start time
# Args: $1 - package name, $2 - temp directory
# Returns: formatted duration like "1.2s"
_calculate_phase_timing() {
    local package_name="$1"
    local temp_dir="$2"
    local status_dir="${temp_dir}/status"
    local start_file="${status_dir}/${package_name}.start"
    
    if [[ ! -f "$start_file" ]]; then
        echo "0.0s"
        return
    fi
    
    local start_time
    start_time=$(cat "$start_file")
    
    if [[ -z "$start_time" ]]; then
        echo "0.0s"
        return
    fi
    
    local current_time=$(date +%s.%N)
    
    # Calculate duration with fallback for systems without bc
    local duration
    if command -v bc &>/dev/null; then
        duration=$(echo "$current_time - $start_time" | bc -l 2>/dev/null || echo "0")
    else
        # Fallback: use awk for floating point arithmetic
        duration=$(awk "BEGIN {printf \"%.1f\", $current_time - $start_time}")
    fi
    
    # Format to 1 decimal place with 's' suffix
    printf "%.1fs" "$duration"
}

# Read current phase from state file
# Args: $1 - package name, $2 - temp directory
# Returns: current phase or "pending"
_get_package_phase() {
    local package_name="$1"
    local temp_dir="$2"
    local status_dir="${temp_dir}/status"
    local phase_file="${status_dir}/${package_name}.phase"
    
    if [[ -f "$phase_file" ]]; then
        cat "$phase_file"
    else
        echo "pending"
    fi
}

# Read completed phase timings
# Args: $1 - package name, $2 - temp directory
# Returns: completed phases with timings, one per line
_get_package_timings() {
    local package_name="$1"
    local temp_dir="$2"
    local status_dir="${temp_dir}/status"
    local phases_file="${status_dir}/${package_name}.phases"
    
    if [[ -f "$phases_file" ]]; then
        cat "$phases_file"
    fi
}

# Function to process output line by line for phase detection
# Args: $1 - package_name, $2 - temp_dir
_process_verify_output() {
    local package_name="$1"
    local temp_dir="$2"
    local line
    while IFS= read -r line; do
        echo "$line"  # Pass through to log file
        
        # Phase detection for dashboard mode
        if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
            local detected_phase
            detected_phase=$(_parse_npm_phase "$line" "$package_name")
            if [[ "$detected_phase" != "unknown" ]]; then
                _update_package_status "$package_name" "$temp_dir" "$detected_phase"
            fi
        fi
    done
}

# Read package status from temp files
_read_package_status() {
    local temp_dir=$1
    local package_name=$2
    local status_dir="${temp_dir}/status"
    
    # Initialize status variables
    local phase="pending"
    local start_time=""
    local phases=""
    
    # Read current phase
    if [[ -f "${status_dir}/${package_name}.phase" ]]; then
        phase=$(cat "${status_dir}/${package_name}.phase" 2>/dev/null || echo "pending")
    fi
    
    # Read phase start time  
    if [[ -f "${status_dir}/${package_name}.start" ]]; then
        start_time=$(cat "${status_dir}/${package_name}.start" 2>/dev/null || echo "")
    fi
    
    # Read completed phases with timings
    if [[ -f "${status_dir}/${package_name}.phases" ]]; then
        phases=$(cat "${status_dir}/${package_name}.phases" 2>/dev/null || echo "")
        # Remove any leading/trailing whitespace and newlines
        phases=$(echo "$phases" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    fi
    
    # Check for completion status from results directory
    local results_dir="${temp_dir}/results"
    if [[ -f "${results_dir}/${package_name}.success" ]]; then
        phase="complete"
    elif [[ -f "${results_dir}/${package_name}.failure" ]]; then
        phase="failed"
    fi
    
    # Output status in format: phase|start_time|phases (convert newlines to spaces)
    local phases_formatted=$(echo "$phases" | tr '\n' ' ' | sed 's/ $//')
    echo "${phase}|${start_time}|${phases_formatted}"
}