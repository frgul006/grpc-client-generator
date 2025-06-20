#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# HELP SYSTEM MODULE
# =============================================================================
# This module contains all help text and help display functions for the Lab CLI.

# =============================================================================
# COMMAND-SPECIFIC HELP FUNCTIONS
# =============================================================================

# Show command-specific help
show_command_help() {
    local cmd="$1"
    case "$cmd" in
        setup)
            show_setup_help
            ;;
        status)
            show_status_help
            ;;
        cleanup)
            show_cleanup_help
            ;;
        version)
            show_version_help
            ;;
        resume)
            show_resume_help
            ;;
        reset)
            show_reset_help
            ;;
        preflight)
            show_preflight_help
            ;;
        publish)
            show_publish_help
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: '$cmd'"
            show_help
            exit 1
            ;;
    esac
}

show_setup_help() {
    cat << 'EOF'
🧪 Lab Setup - Development Environment Setup

USAGE:
    lab setup [OPTIONS]

DESCRIPTION:
    Sets up the complete gRPC development environment including tools,
    Docker services, and configuration.

OPTIONS:
    --verbose       Enable verbose logging with debug output
    --keep-state    Preserve setup state file after completion
    --help          Show this help message

SETUP PROCESS:
    • Install development tools (grpcurl, grpcui, protoc, direnv)
    • Set up Docker network and Verdaccio registry
    • Validate Node.js environment and dependencies
    • Configure direnv for 'lab' command shortcut
    • Run environment smoke tests

EXAMPLES:
    lab setup                    # Standard setup
    lab setup --verbose          # Setup with debug output
    lab setup --keep-state       # Setup and keep state file

RECOVERY:
    If setup fails, use 'lab resume' to continue from last checkpoint
    or 'lab reset' to start fresh.
EOF
}

show_status_help() {
    cat << 'EOF'
📊 Lab Status - Environment Status Check

USAGE:
    lab status [OPTIONS]

DESCRIPTION:
    Shows the current status of development environment components
    including services, tools, and project state.

OPTIONS:
    --help          Show this help message

STATUS CHECKS:
    • Docker network and Verdaccio registry status
    • Port availability (4873, 50052)
    • Project dependencies and configuration
    • Development tool installations
    • Setup progress and state

EXAMPLES:
    lab status                   # Show environment status
EOF
}

show_cleanup_help() {
    cat << 'EOF'
🧹 Lab Cleanup - Environment Cleanup

USAGE:
    lab cleanup [OPTIONS]

DESCRIPTION:
    Stops all running services and cleans up the development environment.
    This will stop Docker containers but preserve installed tools.

OPTIONS:
    --help          Show this help message

CLEANUP ACTIONS:
    • Stop Verdaccio registry container
    • Remove Docker network (if not in use)
    • Clean up temporary files
    • Preserve installed development tools

EXAMPLES:
    lab cleanup                  # Clean up environment
EOF
}

show_version_help() {
    cat << 'EOF'
🔖 Lab Version - Tool Version Information

USAGE:
    lab version [OPTIONS]

DESCRIPTION:
    Shows version information for all development tools and
    environment components.

OPTIONS:
    --help          Show this help message

VERSION INFO:
    • Lab CLI version
    • Development tools (grpcurl, grpcui, protoc)
    • Runtime versions (Node.js, Docker)
    • Environment details

EXAMPLES:
    lab version                  # Show all version information
EOF
}

show_resume_help() {
    cat << 'EOF'
▶️ Lab Resume - Resume Failed Setup

USAGE:
    lab resume [OPTIONS]

DESCRIPTION:
    Resumes setup from the last successful checkpoint. Use this when
    setup fails or is interrupted to continue from where it left off.

OPTIONS:
    --verbose       Enable verbose logging with debug output
    --keep-state    Preserve setup state file after completion
    --help          Show this help message

RESUME PROCESS:
    • Loads previous setup state
    • Validates system consistency
    • Continues from last successful step
    • Skips already completed steps

EXAMPLES:
    lab resume                   # Resume from last checkpoint
    lab resume --verbose         # Resume with debug output

NOTES:
    • Requires a previous setup attempt with state file
    • Use 'lab status' to check current state
    • Use 'lab reset' if you want to start completely fresh
EOF
}

show_reset_help() {
    cat << 'EOF'
🔄 Lab Reset - Clear Setup State

USAGE:
    lab reset [OPTIONS]

DESCRIPTION:
    Clears all setup checkpoints and state, forcing a fresh start
    on the next setup attempt.

OPTIONS:
    --help          Show this help message

RESET ACTIONS:
    • Removes setup state file
    • Clears all checkpoints
    • Forces fresh setup on next run
    • Does not affect installed tools or services

EXAMPLES:
    lab reset                    # Clear all setup state

NOTES:
    • Use this when setup state becomes inconsistent
    • After reset, next 'lab setup' will start from beginning
    • Installed tools and services remain intact
EOF
}

show_preflight_help() {
    cat << 'EOF'
🚀 Lab Preflight - Parallel Package Verification

USAGE:
    lab preflight [OPTIONS]

DESCRIPTION:
    Run 'npm run verify' for all packages in the monorepo that support it.
    
    This command will:
    • Automatically discover packages with verify scripts
    • Run verification in parallel using all CPU cores  
    • Provide clear success/failure summary
    • Exit with proper status codes for CI/CD integration

    The verify script typically runs:
    • Linting (eslint)
    • Type checking (tsc)
    • Code formatting checks (prettier)
    • Unit tests (vitest)
    • Build validation
    • Other quality checks

OPTIONS:
    --verbose       Show detailed output (inherited from global flags)

EXAMPLES:
    lab preflight           # Run verification on all packages
    lab preflight --verbose # Run with detailed logging

EXIT CODES:
    0    All verifications passed
    1    One or more verifications failed

NOTES:
    • Requires jq for JSON parsing (install with brew install jq)
    • Uses staged execution: producers first, then consumers in parallel
    • Each package runs in parallel for maximum speed
    • Failed package logs are shown automatically
    • Perfect for pre-commit hooks and CI/CD pipelines
EOF
}

show_publish_help() {
    cat << 'EOF'
📦 Lab Publish - Publish Package to Local Registry

USAGE:
    lab publish <package-name|path> [OPTIONS]

DESCRIPTION:
    Publishes a package to the local Verdaccio registry with automatic
    version management and dependency updates.

ARGUMENTS:
    package-name    Name of the package (e.g., grpc-client-generator)
    path            Path to the package directory

OPTIONS:
    --verbose       Enable verbose logging with debug output
    --help          Show this help message

PUBLISH PROCESS:
    • Temporarily bumps to unique dev version (0.0.0-dev.timestamp)
    • Builds the package (if build script exists)
    • Publishes to local Verdaccio registry
    • Restores original version
    • Updates all dependent packages in the repository

EXAMPLES:
    lab publish grpc-client-generator     # Publish by package name
    lab publish ./libs/my-package         # Publish by path
    lab publish apis/user-api --verbose   # Publish with debug output

REQUIREMENTS:
    • Verdaccio must be running (use 'lab setup' first)
    • Package must have a valid package.json
    • Package must be within the repository

NOTES:
    • Published packages use dev tag in registry
    • Original version is always restored after publish
    • All packages depending on the published package are updated
    • Updates use the local registry (http://localhost:4873)
EOF
}

# =============================================================================
# MAIN HELP FUNCTION
# =============================================================================

show_help() {
    cat << 'EOF'
🧪 Lab - gRPC Development Environment CLI

USAGE:
    lab <command> [options]
    lab [--help]

COMMANDS:
    setup           Run the development environment setup
    status          Show current status of services and tools
    version         Show version information for all tools
    cleanup         Stop all services and clean up
    resume          Resume setup from last successful checkpoint
    reset           Clear all checkpoints and start fresh
    preflight       Run verify scripts in all packages (parallel)
    publish         Publish package to local registry
    help            Show this help message

GLOBAL OPTIONS:
    --verbose       Enable verbose logging with debug output
    --help          Show this help message

COMMAND-SPECIFIC OPTIONS:
    setup:
      --keep-state  Preserve setup state file after completion

EXAMPLES:
    lab help                     # Show this help
    lab setup                    # Run development environment setup
    lab setup --verbose          # Setup with debug output
    lab setup --keep-state       # Setup with persistent state file
    lab status                   # Check service status
    lab cleanup                  # Stop all services
    lab version                  # Show tool versions
    lab resume                   # Resume from last checkpoint
    lab reset                    # Clear checkpoints and start fresh
    lab publish grpc-client-generator  # Publish package to local registry

COMMAND HELP:
    lab <command> --help         # Show help for specific command
    lab help <command>           # Alternative help syntax

The setup command will:
• Install development tools (grpcurl, grpcui, protoc, direnv)
• Set up Docker network and Verdaccio registry
• Validate Node.js environment and dependencies
• Configure direnv for 'lab' command shortcut
• Run environment smoke tests

After setup, you can use 'lab' from any subdirectory (requires direnv).
EOF
}