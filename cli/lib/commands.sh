#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# COMMAND HANDLERS MODULE
# =============================================================================
# This module contains command parsing, dispatch logic, and individual
# command handler functions for the Lab CLI.


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

# =============================================================================
# INDIVIDUAL COMMAND HANDLERS
# =============================================================================

# Show version information for all tools
show_versions() {
    log_info "🔖 Development Environment Versions"
    echo
    
    # Lab CLI version (from git if available)
    if command -v git &>/dev/null && [ -d "$REPO_ROOT/.git" ]; then
        local lab_version
        lab_version=$(cd "$REPO_ROOT" && git describe --tags --always 2>/dev/null || echo "unknown")
        echo "• Lab CLI: $lab_version"
    else
        echo "• Lab CLI: development"
    fi
    
    # Development tools
    if command -v grpcurl &>/dev/null; then
        local grpcurl_version
        grpcurl_version=$(grpcurl --version 2>&1 | head -n1 || echo "unknown")
        echo "• grpcurl: $grpcurl_version"
    else
        echo "• grpcurl: ❌ Not installed"
    fi
    
    if command -v grpcui &>/dev/null; then
        echo "• grpcui: ✅ Installed"
    else
        echo "• grpcui: ❌ Not installed"
    fi
    
    if command -v protoc &>/dev/null; then
        local protoc_version
        protoc_version=$(protoc --version 2>&1 || echo "unknown")
        echo "• protoc: $protoc_version"
    else
        echo "• protoc: ❌ Not installed"
    fi
    
    # Runtime environments
    if command -v node &>/dev/null; then
        local node_version
        node_version=$(node --version 2>&1 || echo "unknown")
        echo "• Node.js: $node_version"
    else
        echo "• Node.js: ❌ Not installed"
    fi
    
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version 2>&1 | cut -d' ' -f3 | tr -d ',' || echo "unknown")
        echo "• Docker: $docker_version"
    else
        echo "• Docker: ❌ Not installed"
    fi
    
    # System info
    echo "• OS: $(uname -s) $(uname -r)"
    echo "• Architecture: $(uname -m)"
    
    echo
    check_for_updates
}

# Check for available updates
check_for_updates() {
    log_info "🔄 Update Status"
    
    if command -v git &>/dev/null && [ -d "$REPO_ROOT/.git" ]; then
        echo "• Lab CLI: Check 'git status' and 'git pull' for updates"
    else
        echo "• Lab CLI: Manual update required (not a git repository)"
    fi
    
    echo "• Development tools: Use respective package managers (brew, npm, etc.)"
    echo "• Docker: Update via Docker Desktop or package manager"
}

# Show comprehensive status of all services and tools
show_status() {
    log_info "📊 Service Status:"
    echo
    
    # Docker Network Status
    if command -v docker &>/dev/null; then
        if docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$" 2>/dev/null; then
            echo "• Docker Network ($NETWORK_NAME): ✅ Exists"
        else
            echo "• Docker Network ($NETWORK_NAME): ❌ Not found"
        fi
    else
        echo "• Docker Network ($NETWORK_NAME): ❌ Docker not available"
    fi
    
    # Verdaccio Status
    if command -v docker &>/dev/null; then
        local verdaccio_container
        verdaccio_container=$(docker ps --format "{{.Names}}" | grep "verdaccio" | head -n1)
        if [ -n "$verdaccio_container" ]; then
            echo "• Verdaccio Registry: ✅ Running (Docker - http://localhost:4873)"
        else
            local verdaccio_stopped
            verdaccio_stopped=$(docker ps -a --format "{{.Names}}" | grep "verdaccio" | head -n1)
            if [ -n "$verdaccio_stopped" ]; then
                echo "• Verdaccio Registry: ⏸️ Stopped (Docker container exists)"
            else
                echo "• Verdaccio Registry: ❌ Not found"
            fi
        fi
    else
        echo "• Verdaccio Registry: ❌ Docker not available"
    fi
    
    echo
    log_info "🔌 Port Status:"
    
    # Check key ports
    local verdaccio_port_status
    if lsof -i :4873 &>/dev/null; then
        local verdaccio_process
        verdaccio_process=$(lsof -i :4873 -t | head -n1)
        if [ -n "$verdaccio_process" ]; then
            local process_name
            process_name=$(ps -p "$verdaccio_process" -o comm= 2>/dev/null || echo "unknown")
            if [[ "$process_name" == *"docker"* ]] || [[ "$process_name" == *"verdaccio"* ]]; then
                verdaccio_port_status="🟢 In use by Verdaccio (Docker)"
            else
                verdaccio_port_status="🟡 In use by other process ($process_name)"
            fi
        else
            verdaccio_port_status="🟡 In use"
        fi
    else
        verdaccio_port_status="🟢 Available"
    fi
    echo "• Port 4873 (Verdaccio): $verdaccio_port_status"
    
    if lsof -i :50052 &>/dev/null; then
        echo "• Port 50052 (gRPC): 🟡 In use"
    else
        echo "• Port 50052 (gRPC): 🟢 Available"
    fi
    
    if lsof -i :50053 &>/dev/null; then
        echo "• Port 50053 (gRPC): 🟡 In use"
    else
        echo "• Port 50053 (gRPC): 🟢 Available"
    fi
    
    echo
    log_info "📦 Project Status:"
    
    # Check dependencies
    if [ -d "$REPO_ROOT/apis/product-api/node_modules" ]; then
        echo "• Dependencies: ✅ Installed"
    else
        echo "• Dependencies: ❌ Not installed"
    fi
    
    # Check package.json
    if [ -f "$REPO_ROOT/apis/product-api/package.json" ]; then
        echo "• Package.json: ✅ Found"
    else
        echo "• Package.json: ❌ Not found"
    fi
    
    echo
    log_info "🔧 Development Tools:"
    
    # Tool installation status
    if command -v grpcurl &>/dev/null; then
        echo "• grpcurl: ✅ Installed"
    else
        echo "• grpcurl: ❌ Not installed"
    fi
    
    if command -v grpcui &>/dev/null; then
        echo "• grpcui: ✅ Installed"
    else
        echo "• grpcui: ❌ Not installed"
    fi
    
    if command -v protoc &>/dev/null; then
        echo "• protoc: ✅ Installed"
    else
        echo "• protoc: ❌ Not installed"
    fi
    
    if command -v node &>/dev/null; then
        local node_version
        node_version=$(node --version)
        echo "• Node.js: ✅ $node_version"
    else
        echo "• Node.js: ❌ Not installed"
    fi
    
    if command -v docker &>/dev/null; then
        echo "• Docker: ✅ Installed"
    else
        echo "• Docker: ❌ Not installed"
    fi
    
    echo
    log_info "🔄 Setup Progress:"
    
    # Setup state information
    if [ -f "$STATE_FILE" ]; then
        echo "• Setup state file: ✅ Found"
        local completed_steps
        completed_steps=$(grep -c "=COMPLETED" "$STATE_FILE" 2>/dev/null || echo 0)
        echo "• Completed steps: $completed_steps"
        
        if grep -q "=FAILED" "$STATE_FILE" 2>/dev/null; then
            echo "• Status: ⚠️ Has failed steps - run 'lab resume' to continue"
        elif grep -q "=IN_PROGRESS" "$STATE_FILE" 2>/dev/null; then
            echo "• Status: 🔄 Setup in progress - run 'lab resume' to continue"
        else
            echo "• Status: ✅ All tracked steps completed"
        fi
    else
        echo "• Setup appears complete (state file auto-cleaned)"
        echo "• Run 'lab setup --keep-state' to re-create state tracking"
    fi
}

# Clean up running services
cleanup_services() {
    log_info "🧹 Cleaning up development environment..."
    
    # Stop Verdaccio container if running
    if command -v docker &>/dev/null; then
        local verdaccio_container
        verdaccio_container=$(docker ps --format "{{.Names}}" | grep "verdaccio" | head -n1)
        if [ -n "$verdaccio_container" ]; then
            log_info "Stopping Verdaccio container..."
            # Check if this is a docker-compose managed container
            if docker inspect "$verdaccio_container" --format '{{.Config.Labels}}' 2>/dev/null | grep -q 'com.docker.compose'; then
                # Use docker compose to stop it properly
                local compose_project
                compose_project=$(docker inspect "$verdaccio_container" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || echo "")
                if [ -n "$compose_project" ]; then
                    docker compose -p "$compose_project" down &>/dev/null || docker stop "$verdaccio_container" &>/dev/null
                else
                    docker stop "$verdaccio_container" &>/dev/null
                fi
            else
                docker stop "$verdaccio_container" &>/dev/null
            fi
            log_success "Verdaccio container stopped"
        else
            log_info "Verdaccio container is not running"
        fi
        
        # Optionally remove the network if not in use
        if docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$" 2>/dev/null; then
            # Check if network is in use
            local network_in_use
            network_in_use=$(docker network inspect "$NETWORK_NAME" --format "{{.Containers}}" 2>/dev/null)
            if [ "$network_in_use" = "{}" ] || [ -z "$network_in_use" ]; then
                log_info "Removing Docker network..."
                docker network rm "$NETWORK_NAME" &>/dev/null
                log_success "Docker network removed"
            else
                log_info "Docker network is in use, keeping it"
            fi
        fi
    else
        log_warning "Docker not available, skipping container cleanup"
    fi
    
    # Clean up any temporary files
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "Cleaned up state file"
    fi
    
    # Reset npm registry to default
    if command -v npm &>/dev/null; then
        log_info "Resetting npm registry to default..."
        npm config delete registry &>/dev/null || true
        log_success "npm registry reset to default"
    fi
    
    log_success "Environment cleanup completed"
    log_info "💡 Development tools remain installed"
}


