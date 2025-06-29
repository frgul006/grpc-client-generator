#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT MODULE
# =============================================================================
# This module contains the preflight command implementation for parallel
# package verification across the monorepo.

# =============================================================================
# TTY DETECTION AND OUTPUT MODE FUNCTIONS
# =============================================================================

# _is_tty_capable
# Check if the current terminal supports ANSI escape sequences
# Returns 0 (true) if terminal is capable, 1 (false) otherwise
_is_tty_capable() {
    # Check if stdout is a TTY
    [[ -t 1 ]] || return 1
    
    # Check for NO_COLOR environment variable (https://no-color.org/)
    [[ -z "${NO_COLOR:-}" ]] || return 1
    
    # Check for dumb terminal
    [[ "${TERM:-}" != "dumb" ]] || return 1
    
    # Check if terminal supports colors (basic heuristic)
    if [[ -n "${TERM:-}" ]]; then
        case "$TERM" in
            *color* | xterm* | screen* | tmux* | linux* | vt100* | vt220*)
                return 0
                ;;
        esac
    fi
    
    # Default to capable if we have a TTY and no blocking conditions
    return 0
}

# _detect_dashboard_mode
# Core logic to determine if dashboard UI should be used
# Returns 0 (true) for dashboard mode, 1 (false) for verbose mode
_detect_dashboard_mode() {
    # Override: If --verbose or -v flag is set, force verbose output
    if [[ "${VERBOSE_OUTPUT:-false}" == "true" ]]; then
        return 1  # Force verbose mode
    fi
    
    # Environment variable override for testing/debugging
    if [[ "${FORCE_DASHBOARD_MODE:-false}" == "true" ]]; then
        return 0  # Force dashboard mode
    fi
    
    # Check TTY capability
    if ! _is_tty_capable; then
        return 1  # Fall back to verbose mode
    fi
    
    return 0  # Use dashboard mode
}

# _should_use_dashboard
# Master function that combines all checks to determine output mode
# Sets global DASHBOARD_MODE variable and returns the decision
_should_use_dashboard() {
    if _detect_dashboard_mode; then
        DASHBOARD_MODE=true
        return 0
    else
        DASHBOARD_MODE=false
        return 1
    fi
}

# _get_terminal_size
# Get terminal dimensions for dashboard sizing
# Sets global TERMINAL_ROWS and TERMINAL_COLS variables
_get_terminal_size() {
    if command -v tput &>/dev/null && [[ -t 1 ]]; then
        TERMINAL_ROWS=$(tput lines 2>/dev/null || echo "24")
        TERMINAL_COLS=$(tput cols 2>/dev/null || echo "80")
    else
        # Fallback to environment variables or defaults
        TERMINAL_ROWS="${LINES:-24}"
        TERMINAL_COLS="${COLUMNS:-80}"
    fi
    
    # Ensure minimum sensible values
    [[ "$TERMINAL_ROWS" -ge 10 ]] || TERMINAL_ROWS=24
    [[ "$TERMINAL_COLS" -ge 40 ]] || TERMINAL_COLS=80
}

# _setup_output_mode
# Initialize output mode based on detection and set up environment
# This function should be called early in the preflight process
# Args: $1 - optional temp directory path
_setup_output_mode() {
    local temp_dir_arg="${1:-${temp_dir:-}}"
    
    # Initialize global variables
    DASHBOARD_MODE=false
    TERMINAL_ROWS=24
    TERMINAL_COLS=80
    
    # Determine if dashboard mode should be used
    _should_use_dashboard || true  # Don't exit on non-dashboard mode
    
    if [[ "$DASHBOARD_MODE" == "true" ]]; then
        # Get terminal dimensions for dashboard
        _get_terminal_size
        
        # Hide cursor for smoother dashboard updates (only if TTY)
        if [[ -t 1 ]]; then
            tput civis 2>/dev/null || true
        fi
        
        # Set up dashboard state directory
        if [[ -n "$temp_dir_arg" ]]; then
            mkdir -p "${temp_dir_arg}/status"
        fi
    fi
}

# _cleanup_dashboard
# Clean up dashboard-specific resources on exit
# This extends the existing cleanup function
_cleanup_dashboard() {
    if [[ "${DASHBOARD_MODE:-false}" == "true" ]]; then
        # Show cursor again (only if TTY)
        if [[ -t 1 ]]; then
            tput cnorm 2>/dev/null || true
            
            # Clear the dashboard area if we used it
            if [[ -n "${TERMINAL_ROWS:-}" ]]; then
                # Move cursor to bottom and clear from there up
                tput cup "$((TERMINAL_ROWS - 1))" 0 2>/dev/null || true
            fi
        fi
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Parse npm output to detect current phase
# Args: $1 - output line to parse
# Returns: detected phase name or "unknown"
_parse_npm_phase() {
    local line="$1"
    local phase="unknown"
    
    # Convert to lowercase for case-insensitive matching
    local line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
    
    # Lint phase patterns
    if [[ "$line_lower" =~ eslint ]] || [[ "$line" =~ ESLint ]]; then
        phase="lint"
    # Format phase patterns
    elif [[ "$line_lower" =~ prettier ]] || [[ "$line_lower" =~ "checking formatting" ]]; then
        phase="format"
    # Build phase patterns
    elif [[ "$line_lower" =~ tsc ]] || [[ "$line_lower" =~ tsup ]] || [[ "$line_lower" =~ building ]]; then
        phase="build"
    # Test phase patterns
    elif [[ "$line_lower" =~ vitest ]] || [[ "$line" =~ PASS ]] || [[ "$line" =~ FAIL ]]; then
        phase="test"
    # NPM script invocation patterns
    elif [[ "$line" =~ "> ".*" lint" ]]; then
        phase="lint"
    elif [[ "$line" =~ "> ".*" format" ]] || [[ "$line" =~ "> ".*" format:check" ]]; then
        phase="format"
    elif [[ "$line" =~ "> ".*" build" ]] || [[ "$line" =~ "> ".*" prebuild" ]]; then
        phase="build"
    elif [[ "$line" =~ "> ".*" test" ]] || [[ "$line" =~ "> ".*" test:e2e" ]]; then
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
    echo "" > "${status_dir}/${package_name}.phases"
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
            detected_phase=$(_parse_npm_phase "$line")
            if [[ "$detected_phase" != "unknown" ]]; then
                _update_package_status "$package_name" "$temp_dir" "$detected_phase"
            fi
        fi
    done
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

# _start_dashboard_monitor
# Start background process to monitor and render dashboard
# Args: $1 - temp directory path
_start_dashboard_monitor() {
    local temp_dir="$1"
    local update_interval=1  # Update every 1 second
    local last_status=""
    
    # Track dashboard state to avoid unnecessary redraws
    while true; do
        # Check if still needed (exit if temp dir is gone)
        if [[ ! -d "$temp_dir" ]]; then
            break
        fi
        
        # Get current status snapshot
        local current_status=""
        if [[ -d "${temp_dir}/status" ]]; then
            current_status=$(find "${temp_dir}/status" -name "*.phase" -exec cat {} \; 2>/dev/null | sort | tr '\n' '|')
        fi
        
        # Only update if status changed
        if [[ "$current_status" != "$last_status" ]]; then
            _render_dashboard "$temp_dir"
            last_status="$current_status"
        fi
        
        sleep "$update_interval"
    done
}

# =============================================================================
# DASHBOARD RENDERER AND ANSI FUNCTIONS
# =============================================================================

# ANSI utility functions for cursor positioning and control
_cursor_to() {
    local row=$1
    local col=$2
    printf "\033[${row};${col}H"
}

_clear_line() {
    printf "\033[K"
}

_save_cursor() {
    printf "\033[s"
}

_restore_cursor() {
    printf "\033[u"
}

_hide_cursor() {
    printf "\033[?25l"
}

_show_cursor() {
    printf "\033[?25h"
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
    fi
    
    # Check for completion status from results directory
    local results_dir="${temp_dir}/results"
    if [[ -f "${results_dir}/${package_name}.success" ]]; then
        phase="complete"
    elif [[ -f "${results_dir}/${package_name}.failure" ]]; then
        phase="failed"
    fi
    
    # Output status in format: phase|start_time|phases
    echo "${phase}|${start_time}|${phases}"
}

# Format package display line with phases and timings
_format_package_display() {
    local package_name=$1
    local status=$2
    local temp_dir=$3
    
    # Parse status (phase|start_time|phases)
    IFS='|' read -r phase start_time phases <<< "$status"
    
    # Determine status indicator and color
    local indicator=""
    local color=""
    case "$phase" in
        "pending")
            indicator="⏳"
            color="${NC:-}"  # Default/dim
            ;;
        "lint"|"format"|"build"|"test")
            indicator="🟡"
            color="${YELLOW:-}"
            ;;
        "complete")
            indicator="✅"
            color="${GREEN:-}"
            ;;
        "failed")
            indicator="❌"
            color="${RED:-}"
            ;;
        *)
            indicator="⏳"
            color="${NC:-}"
            ;;
    esac
    
    # Format package name with fixed width (20 chars)
    local formatted_name
    printf -v formatted_name "%-20s" "$package_name"
    
    # Build phase display
    local phase_display=""
    if [[ -n "$phases" ]]; then
        # Format completed phases: "lint:1.2s format:0.8s"
        phase_display=$(echo "$phases" | tr '\n' ' ' | sed 's/ $//')
    fi
    
    # Add current phase if in progress
    if [[ "$phase" != "pending" && "$phase" != "complete" && "$phase" != "failed" ]]; then
        if [[ -n "$phase_display" ]]; then
            phase_display="${phase_display} →${phase}"
        else
            phase_display="→${phase}"
        fi
    fi
    
    # Add total time for completed packages
    if [[ "$phase" == "complete" && -n "$phases" ]]; then
        # Calculate total time from individual phase timings
        local total_time
        total_time=$(echo "$phases" | grep -oE '[0-9]+\.[0-9]+s' | sed 's/s$//' | awk '{sum += $1} END {printf "%.1fs", sum}')
        if [[ -n "$total_time" ]]; then
            phase_display="${phase_display} (${total_time})"
        fi
    fi
    
    # Handle pending state
    if [[ "$phase" == "pending" ]]; then
        phase_display="(pending)"
    fi
    
    # Output formatted line
    printf "${color}%s %s%s${NC}" "$indicator" "$formatted_name" "$phase_display"
}

# Main dashboard renderer
_render_dashboard() {
    local temp_dir=$1
    
    # Read package lists from files (created once in main function)
    local producers=()
    local consumers=()
    
    # Read producers list
    if [[ -f "${temp_dir}/producers.list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && producers+=("$line")
        done < "${temp_dir}/producers.list"
    fi
    
    # Read consumers list
    if [[ -f "${temp_dir}/consumers.list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && consumers+=("$line")
        done < "${temp_dir}/consumers.list"
    fi
    
    # If no packages loaded from files yet, check status directory for any packages
    if [[ ${#producers[@]} -eq 0 && ${#consumers[@]} -eq 0 ]]; then
        local status_dir="${temp_dir}/status"
        if [[ -d "$status_dir" ]]; then
            for phase_file in "$status_dir"/*.phase; do
                [[ -f "$phase_file" ]] || continue
                local package_name=$(basename "$phase_file" .phase)
                # Assume all are consumers for now if we can't categorize, use raw package name
                consumers+=("$package_name")
            done
        fi
    fi
    
    # Calculate dashboard dimensions
    local total_packages=$((${#producers[@]} + ${#consumers[@]}))
    
    # If no packages found, don't render dashboard
    if [[ $total_packages -eq 0 ]]; then
        return
    fi
    
    # Clear screen properly for dashboard
    printf "\033[2J\033[H"
    
    # Render header  
    printf "${BLUE}🚀 Preflight Verification (%d packages)${NC}\n" "$total_packages"
    printf "\n"
    
    # Render Stage 1: Core Libraries
    if [[ ${#producers[@]} -gt 0 ]]; then
        printf "${CYAN}Stage 1: Core Libraries${NC}\n"
        for pkg_dir in "${producers[@]}"; do
            local package_name=$(basename "$pkg_dir")
            local status
            status=$(_read_package_status "$temp_dir" "$package_name")
            local display_line
            display_line=$(_format_package_display "$package_name" "$status" "$temp_dir")
            printf "%s\n" "$display_line"
        done
        printf "\n"
    fi
    
    # Render Stage 2: Services (parallel)
    if [[ ${#consumers[@]} -gt 0 ]]; then
        printf "${CYAN}Stage 2: Services (parallel)${NC}\n"
        for pkg_dir in "${consumers[@]}"; do
            local package_name=$(basename "$pkg_dir")
            local status
            status=$(_read_package_status "$temp_dir" "$package_name")
            local display_line
            display_line=$(_format_package_display "$package_name" "$status" "$temp_dir")
            printf "%s\n" "$display_line"
        done
    fi
}

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
        printf '%s
' "${consumers[@]}" | \
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