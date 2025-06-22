#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# COMMAND DISPATCHER MODULE
# =============================================================================
# This module contains command routing and dispatch logic for the Lab CLI.

# =============================================================================
# COMMAND DISPATCHER
# =============================================================================

# Handle the command based on parsed arguments
handle_command() {
    case "$COMMAND" in
        help)
            if [[ $# -gt 0 ]]; then
                # Show help for specific command
                show_command_help "$1"
            else
                show_help
            fi
            ;;
        version)
            show_versions
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup_services
            ;;
        reset)
            clear_checkpoints
            log_info "All setup checkpoints cleared"
            log_info "Next 'lab setup' will start from the beginning"
            ;;
        resume)
            # Validate that there's a state file to resume from
            if [ ! -f "$STATE_FILE" ]; then
                log_error "No setup state found to resume from"
                log_info "💡 Run 'lab setup' to start fresh, or 'lab status' to check current state"
                exit 1
            fi
            
            # Validate state consistency before resuming
            if ! validate_state_consistency; then
                log_warning "State file inconsistencies detected"
                log_info "💡 Consider running 'lab reset' followed by 'lab setup' for a clean start"
                exit 1
            fi
            
            log_info "Resuming setup from last successful checkpoint..."
            COMMAND="setup"  # Continue to setup logic
            ;;
        setup)
            # Setup command continues to main setup logic
            # This is handled in the main script after command processing
            ;;
        preflight)
            handle_preflight_command
            ;;
        dev)
            handle_dev_command
            ;;
        publish)
            # Handle publish command
            publish_package "${COMMAND_ARGS[@]}"
            ;;
        *)
            log_error "Unknown command: '$COMMAND'"
            show_help
            exit 1
            ;;
    esac
}