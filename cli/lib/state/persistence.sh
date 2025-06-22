#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# STATE PERSISTENCE MODULE
# =============================================================================
# This module handles setup state persistence and checkpointing for the Lab CLI.

# =============================================================================
# CORE STATE MANAGEMENT FUNCTIONS
# =============================================================================

# Initialize state file path (called after REPO_ROOT is available)
init_state_file() {
    STATE_FILE="${STATE_FILE:-"$REPO_ROOT/.setup_state"}"
}

# Atomically set checkpoint status
set_checkpoint() {
    local step_name="$1"
    local status="$2"
    
    # Ensure state directory exists
    mkdir -p "$(dirname "$STATE_FILE")"
    
    # Use a temporary file for atomic write
    local temp_file="${STATE_FILE}.tmp.$$"
    
    # Start with existing state (if any)
    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "$temp_file"
    fi
    
    # Update or add the checkpoint
    if grep -q "^${step_name}=" "$temp_file" 2>/dev/null; then
        # Update existing line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^${step_name}=.*/${step_name}=${status}/" "$temp_file"
        else
            sed -i "s/^${step_name}=.*/${step_name}=${status}/" "$temp_file"
        fi
    else
        # Add new line
        echo "${step_name}=${status}" >> "$temp_file"
    fi
    
    # Atomic replace
    mv "$temp_file" "$STATE_FILE"
    log_debug "Checkpoint set: $step_name = $status"
}

# Get checkpoint status
get_checkpoint() {
    local step_name="$1"
    
    if [ ! -f "$STATE_FILE" ]; then
        echo "PENDING"
        return
    fi
    
    local checkpoint_status
    checkpoint_status=$(grep "^${step_name}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 || true)
    echo "${checkpoint_status:-PENDING}"
}

# Clear all checkpoints (remove state file)
clear_checkpoints() {
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "All checkpoints cleared"
    fi
}

# Automatic state cleanup after successful completion
auto_cleanup_state() {
    # Check if --keep-state flag was used (via KEEP_STATE_MODE variable)
    if [ "$KEEP_STATE_MODE" = true ]; then
        log_info "State file preserved (--keep-state flag used)"
        return 0
    fi
    
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "Setup state cleaned up automatically (use --keep-state to preserve)"
    fi
}

# Validate state file against actual system state
validate_state_consistency() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1  # No state file to validate
    fi
    
    local inconsistencies=0
    local warnings=()
    
    # Check if state says tools are installed but they're not
    if grep -q "TOOL_GRPCURL_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v grpcurl &>/dev/null; then
            warnings+=("grpcurl marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    if grep -q "TOOL_GRPCUI_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v grpcui &>/dev/null; then
            warnings+=("grpcui marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    if grep -q "TOOL_PROTOC_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v protoc &>/dev/null; then
            warnings+=("protoc marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Check if Docker network state is consistent
    if grep -q "DOCKER_NETWORK_CREATE=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$" 2>/dev/null; then
            warnings+=("Docker network marked as created but not found")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Check if dependencies state is consistent
    if grep -q "DEPENDENCIES_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if [ ! -d "$REPO_ROOT/apis/product-api/node_modules" ]; then
            warnings+=("Dependencies marked as installed but node_modules not found")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Report findings
    if [ $inconsistencies -gt 0 ]; then
        log_warning "State file inconsistencies detected:"
        for warning in "${warnings[@]}"; do
            log_warning "  • $warning"
        done
        log_info "Consider running 'lab reset' to start fresh"
        return 1
    fi
    
    return 0
}