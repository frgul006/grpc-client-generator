#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# ARGUMENT PARSING MODULE
# =============================================================================
# This module contains argument parsing and validation logic for the Lab CLI.

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

# Parse command line arguments
parse_args() {
    COMMAND=""
    KEEP_STATE_MODE=false
    VERBOSE_MODE=false
    COMMAND_ARGS=()
    
    # Handle special case: lab help <command>
    if [[ $# -ge 2 && "$1" == "help" && ! "$2" =~ ^-- ]]; then
        show_command_help "$2"
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                COMMAND="help"
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --keep-state)
                KEEP_STATE_MODE=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                else
                    # Store additional arguments for commands that need them
                    COMMAND_ARGS+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Default to help if no command specified
    if [[ -z "$COMMAND" ]]; then
        COMMAND="help"
    fi
    
    # Validate command and flag combinations
    case "$COMMAND" in
        setup|resume)
            # These commands support all flags
            ;;
        help|status|version|cleanup|reset)
            # These commands don't support --keep-state
            if [[ "$KEEP_STATE_MODE" == true ]]; then
                log_error "Command '$COMMAND' does not support --keep-state flag"
                exit 1
            fi
            ;;
        preflight)
            # Preflight command doesn't support --keep-state
            if [[ "$KEEP_STATE_MODE" == true ]]; then
                log_error "Command '$COMMAND' does not support --keep-state flag"
                exit 1
            fi
            ;;
        dev)
            # Dev command doesn't support --keep-state
            if [[ "$KEEP_STATE_MODE" == true ]]; then
                log_error "Command '$COMMAND' does not support --keep-state flag"
                exit 1
            fi
            ;;
        publish)
            # Publish command doesn't support --keep-state
            if [[ "$KEEP_STATE_MODE" == true ]]; then
                log_error "Command '$COMMAND' does not support --keep-state flag"
                exit 1
            fi
            # Publish requires an argument
            if [[ ${#COMMAND_ARGS[@]} -eq 0 ]]; then
                log_error "Command '$COMMAND' requires a package name or path"
                log_info "Usage: lab publish <package-name|path>"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown command: '$COMMAND'"
            show_help
            exit 1
            ;;
    esac
    
    # Enable debug logging if verbose mode is on
    # DEBUG_MODE is already handled by VERBOSE_MODE
}