#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# PREFLIGHT DASHBOARD MODULE
# =============================================================================
# This module handles dashboard rendering and ANSI control sequences for the
# preflight command's visual interface.

# =============================================================================
# ANSI UTILITY FUNCTIONS
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

# =============================================================================
# DASHBOARD RENDERING FUNCTIONS
# =============================================================================

# Format package display line with phases and timings
_format_package_display() {
    local package_name=$1
    local package_status=$2
    local temp_dir=$3
    
    # Parse status (phase|start_time|phases)
    IFS='|' read -r phase start_time phases <<< "$package_status"
    
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
    
    # Format package name with appropriate width (25 chars to handle longer names)
    local formatted_name
    printf -v formatted_name "%-25s" "$package_name"
    
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