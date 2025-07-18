#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# STATE EXECUTION MODULE
# =============================================================================
# This module handles error handling, retry mechanisms, and step execution for the Lab CLI.

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# State file for tracking setup progress (will be set after REPO_ROOT is available)
STATE_FILE=""

# Current step being executed (for error handling)
CURRENT_STEP=""

# Process ID for cleanup
SCRIPT_PID=$$

# Retry configuration
MAX_RETRY_ATTEMPTS=3
BASE_RETRY_DELAY=2

# Timeout configurations (seconds)
NETWORK_TIMEOUT=30
DOCKER_TIMEOUT=60
VERDACCIO_TIMEOUT=120
TOOL_INSTALL_TIMEOUT=300

# =============================================================================
# ERROR HANDLING AND RECOVERY
# =============================================================================

# Global error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command_text="$3"
    
    # Mark current step as failed if we're in one
    if [[ -n "$CURRENT_STEP" ]]; then
        set_checkpoint "$CURRENT_STEP" "FAILED"
    fi
    
    log_error "Error on line ${line_number}: command exited with code ${exit_code}"
    log_error "Failing command: ${command_text}"
    
    # Provide recovery suggestion
    log_info "💡 Recovery options:"
    log_info "   • Run 'lab status' to check current state"
    log_info "   • Run 'lab resume' to continue from last checkpoint"
    log_info "   • Run 'lab reset' to start fresh"
    
    exit "$exit_code"
}

handle_interrupt() {
    log_warning "Setup interrupted by user"
    
    # Mark current step as failed if we're in one
    if [[ -n "$CURRENT_STEP" ]]; then
        set_checkpoint "$CURRENT_STEP" "FAILED"
        log_info "Marked step '$CURRENT_STEP' as failed"
    fi
    
    log_info "💡 Use 'lab resume' to continue from last successful step"
    exit 130
}

# Set up global traps
setup_error_handlers() {
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
    trap 'handle_interrupt' SIGINT
}

# =============================================================================
# RETRY MECHANISMS
# =============================================================================

# Retry mechanism with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        
        # Exponential backoff with jitter
        local delay=$((base_delay * attempt))
        local jitter=$((RANDOM % 3))
        delay=$((delay + jitter))
        
        log_warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}

# =============================================================================
# STEP EXECUTION WITH CHECKPOINTING
# =============================================================================

# Enhanced step execution with checkpointing
run_step() {
    local step_name="$1"
    shift
    local command_to_run=("$@")
    
    local step_status
    step_status=$(get_checkpoint "$step_name")
    
    if [[ "$step_status" == "COMPLETED" ]]; then
        log_success "Skipping step '$step_name': already completed"
        return 0
    fi
    
    log_debug "Starting step: $step_name"
    CURRENT_STEP="$step_name"
    set_checkpoint "$step_name" "IN_PROGRESS"
    
    # Execute the command
    "${command_to_run[@]}"
    
    set_checkpoint "$step_name" "COMPLETED"
    CURRENT_STEP=""
    log_debug "Completed step: $step_name"
}

# Enhanced error reporting with context and categorization
report_error() {
    local error_code="$1"
    local component="$2"
    local operation="$3"
    local suggestion="$4"
    local severity="${5:-FATAL}"  # FATAL, RECOVERABLE, DEGRADED
    
    case "$severity" in
        "FATAL")
            log_error "FATAL ERROR $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup cannot continue. Fix this issue and run 'lab resume'"
            ;;
        "RECOVERABLE")
            log_warning "RECOVERABLE ERROR $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup will retry automatically"
            ;;
        "DEGRADED")
            log_warning "NON-CRITICAL ISSUE $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup will continue but functionality may be limited"
            ;;
    esac
    
    log_info "Run 'lab status' to check current state"
}

# Graceful degradation for non-critical operations
run_step_degraded() {
    local step_name="$1"
    shift
    local command_to_run=("$@")
    
    local step_status
    step_status=$(get_checkpoint "$step_name")
    
    if [[ "$step_status" == "COMPLETED" ]]; then
        log_success "Skipping step '$step_name': already completed"
        return 0
    fi
    
    log_debug "Starting optional step: $step_name"
    CURRENT_STEP="$step_name"
    set_checkpoint "$step_name" "IN_PROGRESS"
    
    # Execute the command with degraded error handling
    if "${command_to_run[@]}"; then
        set_checkpoint "$step_name" "COMPLETED"
        CURRENT_STEP=""
        log_debug "Completed optional step: $step_name"
        return 0
    else
        set_checkpoint "$step_name" "DEGRADED"
        CURRENT_STEP=""
        log_warning "Optional step '$step_name' failed - continuing setup"
        return 0  # Return success to continue setup
    fi
}

# =============================================================================
# TIMEOUT AND PROGRESS HANDLING
# =============================================================================

# Enhanced timeout with progress indication
timeout_with_progress() {
    local timeout_seconds="$1"
    local progress_message="$2"
    shift 2
    local command=("$@")
    
    # Run command in background
    "${command[@]}" &
    local cmd_pid=$!
    
    # Show progress while waiting
    local counter=0
    while [ $counter -lt $timeout_seconds ]; do
        if ! kill -0 $cmd_pid 2>/dev/null; then
            # Command finished
            wait $cmd_pid
            return $?
        fi
        
        # Update progress indicator
        local dots=$((counter / 2 % 4))
        local progress_dots=$(printf "%*s" $dots | tr ' ' '.')
        printf "\r${CYAN}[%s] 🔄 %s%s (${counter}s/${timeout_seconds}s)${NC}" \
            "$(date '+%H:%M:%S')" "$progress_message" "$progress_dots"
        
        sleep 2
        counter=$((counter + 2))
    done
    
    # Timeout reached - kill the command
    if kill -0 $cmd_pid 2>/dev/null; then
        kill $cmd_pid 2>/dev/null
        wait $cmd_pid 2>/dev/null
        printf "\n"
        log_warning "Operation timed out after ${timeout_seconds} seconds"
        return 124  # Standard timeout exit code
    fi
}

# =============================================================================
# SPECIALIZED HELPER FUNCTIONS FOR RETRY OPERATIONS
# =============================================================================

# Tool installation with retry and idempotency
install_tool_with_retry() {
    local tool_name="$1"
    local check_command="$2"
    shift 2
    local install_command=("$@")
    
    # Check if tool is already installed
    if bash -c "$check_command" &>/dev/null; then
        log_success "$tool_name is already installed"
        return 0
    fi
    
    log_debug "Installing $tool_name..."
    if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY "${install_command[@]}"; then
        log_success "$tool_name installed successfully"
        return 0
    else
        report_error "TOOL_INSTALL_FAILED" "$tool_name" "installation" "Check network connection and package manager"
        return 1
    fi
}

# Docker operation with retry
docker_operation_with_retry() {
    local operation_name="$1"
    shift
    local docker_command=("$@")
    
    log_debug "Executing Docker operation: $operation_name"
    if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY "${docker_command[@]}"; then
        log_success "Docker operation '$operation_name' completed"
        return 0
    else
        report_error "DOCKER_OPERATION_FAILED" "Docker" "$operation_name" "Check Docker daemon status and network connectivity"
        return 1
    fi
}

# Safe command execution with validation
safe_execute() {
    local step_name="$1"
    local validation_command="$2"
    shift 2
    local command=("$@")
    
    # Check if already satisfied
    if bash -c "$validation_command" &>/dev/null; then
        log_success "Step '$step_name': already satisfied"
        return 0
    fi
    
    # Execute command
    log_debug "Executing: $step_name"
    "${command[@]}"
    
    # Validate result
    if bash -c "$validation_command" &>/dev/null; then
        log_success "Step '$step_name': completed and validated"
        return 0
    else
        log_error "Step '$step_name': validation failed after execution"
        return 1
    fi
}