#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# INFRASTRUCTURE SETUP MODULE
# =============================================================================
# This module contains Docker and service setup operations for the Lab CLI.

# =============================================================================
# INFRASTRUCTURE SETUP
# =============================================================================

# Create Docker network
create_docker_network() {
    log_debug "Setting up Docker network..."
    
    if docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
        log_success "Docker network '$NETWORK_NAME' already exists"
        return 0
    fi
    
    if docker network create "$NETWORK_NAME" &>/dev/null; then
        log_success "Docker network '$NETWORK_NAME' created"
        return 0
    else
        log_error "Failed to create Docker network '$NETWORK_NAME'"
        return 1
    fi
}

# Setup Verdaccio NPM registry
setup_verdaccio() {
    log_debug "Setting up Verdaccio NPM registry..."
    
    # Check if Verdaccio is already running
    if docker ps --format "{{.Names}}" | grep -q "verdaccio"; then
        log_success "Verdaccio registry is already running"
        return 0
    fi
    
    # Check if there's a stopped Verdaccio container
    if docker ps -a --format "{{.Names}}" | grep -q "verdaccio"; then
        log_info "Starting existing Verdaccio container..."
        docker_operation_with_retry "start verdaccio" docker start verdaccio
    else
        log_info "Starting Docker registry..."
        cd "$REPO_ROOT/registry" || return 1
        docker_operation_with_retry "docker compose up" docker compose up -d
        cd - >/dev/null
    fi
    
    # Wait for Verdaccio to be ready
    log_info "Waiting for Verdaccio to be ready..."
    local timeout=0
    while [ $timeout -lt $VERDACCIO_TIMEOUT ]; do
        if curl -sf http://localhost:4873 &>/dev/null; then
            log_success "Verdaccio registry is ready at http://localhost:4873"
            return 0
        fi
        sleep 2
        timeout=$((timeout + 2))
    done
    
    log_error "Verdaccio registry failed to start within ${VERDACCIO_TIMEOUT} seconds"
    return 1
}

# Install Node.js dependencies
install_dependencies() {
    log_debug "Installing Node.js dependencies..."
    
    local api_dir="$REPO_ROOT/apis/product-api"
    
    if [ ! -f "$api_dir/package.json" ]; then
        log_error "package.json not found in $api_dir"
        return 1
    fi
    
    # Install dependencies for all workspaces from root
    (
        cd "$REPO_ROOT" || exit 1
        
        # In workspace mode, install all dependencies from root
        # This installs dependencies for all workspace packages automatically
        if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY npm install; then
            log_success "Dependencies installed successfully for all workspaces"
            return 0
        else
            log_error "Failed to install workspace dependencies"
            return 1
        fi
    )
}

# Setup direnv environment
setup_direnv_environment() {
    log_debug "Setting up direnv environment..."
    
    # Create .envrc if it doesn't exist
    if [ ! -f "$REPO_ROOT/.envrc" ]; then
        log_info "Creating .envrc file..."
        cat > "$REPO_ROOT/.envrc" << 'EOF'
# Lab CLI shortcut
export PATH="$PWD/cli:$PATH"

# Development environment variables
export GRPC_VERBOSITY=ERROR
export NODE_ENV=development
EOF
        log_success ".envrc file created"
    fi
    
    # Allow the .envrc file
    (cd "$REPO_ROOT" && direnv allow .) &>/dev/null
    log_success "direnv environment configured"
    
    return 0
}