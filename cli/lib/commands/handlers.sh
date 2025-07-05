#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# INDIVIDUAL COMMAND HANDLERS MODULE
# =============================================================================
# This module contains individual command handler functions for the Lab CLI.

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
    log_info "🔄 Registry Mode:"
    
    # Check current registry configuration
    local current_registry
    current_registry=$(npm config get registry)
    local registry_mode
    registry_mode=$(get_current_registry_mode)
    
    if [[ "$registry_mode" == "local" ]]; then
        echo "• Active Mode: 🟢 LOCAL REGISTRY ($VERDACCIO_URL)"
        echo "• Status: Enhanced development mode active"
        echo "• Auto-Publishing: ✅ Enabled for library changes"
    else
        echo "• Active Mode: 🟡 DEFAULT REGISTRY (npmjs.org)"  
        echo "• Status: Standard workspace mode"
        echo "• Auto-Publishing: ❌ Disabled (no local registry)"
    fi
    
    echo "• Current Registry: $current_registry"
    
    echo
    log_info "🔧 Development Workflow:"
    
    # Check file watcher status
    if pgrep -f "chokidar.*libs" >/dev/null 2>&1; then
        echo "• File Watcher: 🟢 Active (monitoring libs/ directory)"
    else
        echo "• File Watcher: ⚪ Inactive"
    fi
    
    # Check development servers
    local dev_processes=0
    if pgrep -f "npm run dev" >/dev/null 2>&1; then
        dev_processes=$(pgrep -f "npm run dev" 2>/dev/null | wc -l)
        dev_processes=${dev_processes:-0}
    fi
    if [[ "$dev_processes" -gt 0 ]]; then
        echo "• Dev Servers: 🟢 Running ($dev_processes processes)"
    else
        echo "• Dev Servers: ⚪ Not running"
    fi
    
    # Check workspace dependencies
    if [[ -f "$REPO_ROOT/services/example-service/package.json" ]]; then
        local grpc_dep
        grpc_dep=$(grep -o '"grpc-client-generator": "[^"]*"' "$REPO_ROOT/services/example-service/package.json" | cut -d'"' -f4)
        if [[ -n "$grpc_dep" ]]; then
            echo "• Consumer Dependencies: $grpc_dep"
        else
            echo "• Consumer Dependencies: ❌ Not found"
        fi
    else
        echo "• Consumer Dependencies: ❌ example-service not found"
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

# Show development mode summary
show_dev_mode_summary() {
    echo
    log_info "📋 Development Mode Summary:"
    echo "   • Registry: $(get_current_registry_mode | tr '[:lower:]' '[:upper:]')"
    echo "   • Local Registry: $(check_verdaccio_running && echo "AVAILABLE" || echo "UNAVAILABLE")"
    echo "   • File Watcher: $([ -d "libs" ] && echo "ENABLED" || echo "DISABLED")"
    echo "   • Auto-Publishing: $(check_verdaccio_running && echo "ENABLED" || echo "DISABLED")"
    echo
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

# Handle dev command - orchestrate development environment
handle_dev_command() {
    log_info "🚀 Starting all development servers..."
    
    # Check if we're in the repository root
    if [[ ! -f "$REPO_ROOT/package.json" ]]; then
        log_error "Root package.json not found. Please run 'npm install' in the repository root first."
        exit 1
    fi
    
    # Ensure dependencies are installed
    if [[ ! -d "$REPO_ROOT/node_modules" ]]; then
        log_info "Installing root dependencies..."
        (cd "$REPO_ROOT" && npm install) || {
            log_error "Failed to install root dependencies"
            exit 1
        }
    fi
    
    # =============================================================================
    # AUTOMATIC REGISTRY MODE SETUP
    # =============================================================================
    
    log_info "🔧 Setting up enhanced local development mode..."
    
    # Check if Verdaccio is running, start if needed
    if ! check_verdaccio_running; then
        log_info "🚀 Starting local registry (Verdaccio)..."
        if setup_verdaccio; then
            log_success "✅ Local registry ready at $VERDACCIO_URL"
        else
            log_warning "⚠️  Failed to start local registry, falling back to workspace mode"
            log_info "💡 File changes will use workspace dependencies only"
        fi
    fi
    
    # Switch to local registry if Verdaccio is available
    if check_verdaccio_running; then
        switch_to_local_registry
        log_info "🔄 Registry mode: LOCAL (auto-publishing enabled)"
    else
        log_info "🔄 Registry mode: WORKSPACE (local dependencies only)"
    fi
    
    # Discover packages with dev scripts
    local packages=()
    for dir in apis libs services; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            packages+=($(find "$REPO_ROOT/$dir" -mindepth 1 -maxdepth 1 -type d))
        fi
    done
    
    # Build concurrently command arguments
    local commands=()
    local names=()
    for pkg in "${packages[@]}"; do
        if [[ -f "$pkg/package.json" ]] && command -v node >/dev/null 2>&1; then
            # Use Node.js to check if dev script exists (more robust than jq)
            local has_dev_script
            has_dev_script=$(node -p "
                try {
                    const pkg = require('$pkg/package.json');
                    pkg.scripts && pkg.scripts.dev ? 'true' : 'false';
                } catch (e) {
                    'false';
                }
            " 2>/dev/null || echo "false")
            
            if [[ "$has_dev_script" == "true" ]]; then
                local pkg_name=$(basename "$pkg")
                commands+=("npm run dev --prefix $pkg")
                names+=("$pkg_name")
            fi
        fi
    done
    
    if [[ ${#commands[@]} -eq 0 ]]; then
        log_error "No packages with dev scripts found"
        log_info "💡 Make sure packages in /apis, /libs, and /services have 'dev' scripts in their package.json"
        exit 1
    fi
    
    log_info "📦 Found ${#commands[@]} packages with dev scripts: $(IFS=', '; echo "${names[*]}")"
    
    # Enhanced startup summary
    log_info "📋 Development Mode Summary:"
    log_info "   • Registry: $(get_current_registry_mode | tr '[:lower:]' '[:upper:]')"
    log_info "   • File Watcher: $([ -d "$REPO_ROOT/libs" ] && echo "ENABLED" || echo "DISABLED")"
    log_info "   • Auto-Publishing: $(check_verdaccio_running && echo "ENABLED" || echo "DISABLED")"
    
    # Start file watcher for libraries in background
    local watcher_pid=""
    if [[ -d "$REPO_ROOT/libs" ]]; then
        log_info "👀 Starting file watcher for libraries..."
        
        # Create log directory if it doesn't exist
        mkdir -p "$REPO_ROOT/.lab"
        
        # Start chokidar watcher with enhanced debouncing and proper ignore patterns
        # Note: --initial flag omitted to avoid publishing all libraries on startup
        # Watch only source files (.ts, .js) and config files, but exclude package management files
        npx chokidar 'libs/**/*.{ts,js}' \
            --ignore 'libs/**/node_modules/**' \
            --ignore 'libs/**/dist/**' \
            --ignore 'libs/**/lib/**' \
            --ignore 'libs/**/.git/**' \
            --debounce 1000 \
            -c "$REPO_ROOT/.lab/scripts/handle-lib-change.sh {path}" \
            > "$REPO_ROOT/.lab/watcher.log" 2>&1 &
        
        watcher_pid=$!
        log_success "File watcher started (PID: $watcher_pid)"
    else
        log_info "📁 No libs directory found, skipping file watcher"
    fi
    
    # Set up signal handling for graceful shutdown
    local cleanup_done=false
    cleanup() {
        if [[ "$cleanup_done" == "true" ]]; then
            return 0
        fi
        cleanup_done=true
        
        echo "🛑 Shutting down all processes..."
        if [[ -n "$watcher_pid" ]]; then
            kill "$watcher_pid" 2>/dev/null || true
        fi
        
        # Reset npm registry to default
        if is_local_registry_active; then
            log_info "🔄 Resetting npm registry to default..."
            switch_to_default_registry
        fi
        
        kill 0 2>/dev/null || true
    }
    trap cleanup SIGINT SIGTERM EXIT
    
    # Run with concurrently using expert analysis recommendations
    npx concurrently \
        --names "$(IFS=','; echo "${names[*]}")" \
        --prefix-colors "auto" \
        --kill-others=false \
        "${commands[@]}"
}