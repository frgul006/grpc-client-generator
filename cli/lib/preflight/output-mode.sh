#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT OUTPUT MODE MODULE
# =============================================================================
# This module handles TTY detection and output mode selection for the preflight
# command, determining whether to use dashboard or verbose mode.

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