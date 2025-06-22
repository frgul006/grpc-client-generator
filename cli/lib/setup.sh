#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# SETUP OPERATIONS MODULE
# =============================================================================
# This module contains all setup operations for the Lab CLI including
# tool installation, environment validation, and service configuration.

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate Node.js and npm installation
validate_nodejs() {
    log_debug "Validating Node.js environment..."
    
    if ! command -v node &>/dev/null; then
        log_error "Node.js is not installed"
        log_info "💡 Please install Node.js from https://nodejs.org/"
        return 1
    fi
    
    if ! command -v npm &>/dev/null; then
        log_error "npm is not installed"
        log_info "💡 npm should come with Node.js installation"
        return 1
    fi
    
    # Check Node.js version (require >= 16)
    local node_version
    node_version=$(node -v | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d'.' -f1)
    
    if [ "$major_version" -lt 14 ]; then
        log_error "Node.js version $node_version is too old (require >= 14.0.0)"
        log_info "💡 Please update Node.js from https://nodejs.org/"
        return 1
    fi
    
    log_success "Node.js environment is ready (v$node_version)"
    return 0
}

# Check for port conflicts
check_port_conflicts() {
    log_debug "Checking for port conflicts..."
    
    local conflicts_found=false
    
    # Check port 4873 (Verdaccio) - handle lsof exit codes properly with set -e
    local port_4873_in_use=false
    lsof -i :4873 &>/dev/null && port_4873_in_use=true || true
    
    if [ "$port_4873_in_use" = true ]; then
        local process_info
        process_info=$(lsof -i :4873 -n 2>/dev/null | grep LISTEN | head -n1 || true)
        if [ -n "$process_info" ]; then
            if echo "$process_info" | grep -q "verdaccio\|docker"; then
                log_info "Port 4873 is in use by existing Verdaccio instance"
            else
                log_warning "Port 4873 is in use by another process:"
                log_warning "  $process_info"
                conflicts_found=true
            fi
        fi
    fi
    
    # Check port 50052 (gRPC) - handle lsof exit codes properly with set -e
    local port_50052_in_use=false
    lsof -i :50052 &>/dev/null && port_50052_in_use=true || true
    
    if [ "$port_50052_in_use" = true ]; then
        local process_info
        process_info=$(lsof -i :50052 -n 2>/dev/null | grep LISTEN | head -n1 || true)
        if [ -n "$process_info" ]; then
            log_warning "Port 50052 is in use by another process:"
            log_warning "  $process_info"
            log_info "💡 This may cause issues with gRPC services"
        fi
    fi
    
    if [ "$conflicts_found" = true ]; then
        log_info "💡 Consider stopping conflicting processes or using different ports"
        log_warning "Port conflicts detected but setup will continue"
    fi
    
    # Always return 0 since this is a non-critical check
    return 0
}

# Validate Git installation
validate_git() {
    log_debug "Validating Git installation..."
    
    if ! command -v git &>/dev/null; then
        log_error "Git is not installed"
        log_info "💡 Please install Git for your operating system"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warning "Not in a Git repository"
        log_info "💡 Some features may be limited"
    else
        log_success "Git environment is ready"
    fi
    
    return 0
}

# Validate direnv installation and configuration
validate_direnv() {
    log_debug "Validating direnv installation..."
    
    if ! command -v direnv &>/dev/null; then
        log_error "direnv is not installed"
        log_info "💡 Please install direnv for your operating system"
        return 1
    fi
    
    # Check if direnv is hooked to shell
    if ! direnv status &>/dev/null; then
        log_warning "direnv is not properly configured"
        log_info "💡 Add 'eval \"\$(direnv hook bash)\"' to your shell profile"
        log_info "   Then restart your shell or run: source ~/.bashrc"
        return 1
    fi
    
    # Check if .envrc exists
    if [ ! -f "$REPO_ROOT/.envrc" ]; then
        log_info "Creating .envrc file for lab command shortcut..."
        cat > "$REPO_ROOT/.envrc" << 'EOF'
# Lab CLI shortcut
export PATH="$PWD/cli:$PATH"
EOF
        log_success ".envrc file created"
        
        # Allow the .envrc file
        (cd "$REPO_ROOT" && direnv allow .) &>/dev/null
        log_success "direnv configuration allowed"
    else
        log_success "direnv environment is ready"
    fi
    
    return 0
}

# Validate Docker installation
validate_docker() {
    log_debug "Validating Docker installation..."
    
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        log_info "💡 Please install Docker Desktop or Docker Engine"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running"
        log_info "💡 Please start Docker Desktop or Docker service"
        return 1
    fi
    
    log_success "Docker environment is ready"
    return 0
}

# =============================================================================
# OS AND TOOL INSTALLATION
# =============================================================================

# Validate OS and package manager
validate_os_and_package_manager() {
    log_debug "Detecting operating system..."
    
    case "$OSTYPE" in
        darwin*)
            log_info "Detected macOS"
            install_tools_macos
            ;;
        linux*)
            log_info "Detected Linux"
            install_tools_linux
            ;;
        *)
            log_warning "Unsupported operating system: $OSTYPE"
            install_tools_unsupported
            ;;
    esac
}

# macOS tool installation
install_tools_macos() {
    log_info "Setting up development tools for macOS..."
    
    # Check if Homebrew is available
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew is not installed"
        log_info "💡 Install Homebrew from https://brew.sh/"
        return 1
    fi
    
    # Install tools using Homebrew
    local tools=("grpcurl" "grpcui" "protobuf" "direnv")
    
    for tool in "${tools[@]}"; do
        install_tool_with_retry "$tool" "command -v ${tool/protobuf/protoc}" brew install "$tool"
    done
}

# Linux tool installation
install_tools_linux() {
    log_info "Setting up development tools for Linux..."
    log_info "💡 Please install the following tools manually:"
    log_info "   • grpcurl: https://github.com/fullstorydev/grpcurl"
    log_info "   • grpcui: https://github.com/fullstorydev/grpcui"
    log_info "   • protoc: https://github.com/protocolbuffers/protobuf"
    log_info "   • direnv: https://direnv.net/"
    
    # Basic validation that tools are available
    validate_tool_installed "grpcurl"
    validate_tool_installed "grpcui"
    validate_tool_installed "protoc"
    validate_tool_installed "direnv"
}

# Unsupported OS handling
install_tools_unsupported() {
    log_warning "Automatic tool installation not supported on this OS"
    log_info "💡 Please install the following tools manually:"
    log_info "   • grpcurl: https://github.com/fullstorydev/grpcurl"
    log_info "   • grpcui: https://github.com/fullstorydev/grpcui"
    log_info "   • protoc: https://github.com/protocolbuffers/protobuf"
    log_info "   • direnv: https://direnv.net/"
    
    # Basic validation that tools are available
    validate_tool_installed "grpcurl"
    validate_tool_installed "grpcui"
    validate_tool_installed "protoc"
    validate_tool_installed "direnv"
}

# Validate individual tool installation
validate_tool_installed() {
    local tool_name="$1"
    
    if command -v "$tool_name" &>/dev/null; then
        log_success "$tool_name is installed"
        return 0
    else
        log_error "$tool_name is not installed"
        return 1
    fi
}

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
    
    # Change to API directory and install dependencies
    (
        cd "$api_dir" || exit 1
        
        # Configure npm to use Verdaccio registry
        npm config set registry http://localhost:4873
        
        # Install dependencies with retry
        if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY npm install; then
            log_success "Dependencies installed successfully"
            
            # Reset npm registry to default
            npm config set registry https://registry.npmjs.org/
            return 0
        else
            log_error "Failed to install dependencies"
            # Reset npm registry to default
            npm config set registry https://registry.npmjs.org/
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

# =============================================================================
# TESTING AND VALIDATION
# =============================================================================

# Test Verdaccio accessibility
test_verdaccio_accessibility() {
    log_debug "Testing Verdaccio accessibility..."
    
    if curl -sf http://localhost:4873 &>/dev/null; then
        log_success "Verdaccio registry is accessible"
        return 0
    else
        log_error "Verdaccio registry is not accessible"
        return 1
    fi
}

# Test protoc code generation
test_protoc_generation() {
    log_debug "Testing protoc code generation..."
    
    local proto_file="$REPO_ROOT/protos/product.proto"
    if [ ! -f "$proto_file" ]; then
        log_warning "protoc test skipped: product.proto not found"
        return 0
    fi
    
    # Test basic protoc functionality (descriptor generation)
    local temp_dir
    temp_dir=$(mktemp -d)
    if protoc --descriptor_set_out="$temp_dir/test.pb" --proto_path="$REPO_ROOT/protos" "$proto_file" &>/dev/null; then
        log_success "protoc code generation test passed"
        rm -rf "$temp_dir"
        return 0
    else
        log_warning "protoc code generation test failed"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test TypeScript compilation
test_typescript_compilation() {
    log_debug "Testing TypeScript compilation..."
    
    local api_dir="$REPO_ROOT/apis/product-api"
    
    if [ ! -d "$api_dir/node_modules" ]; then
        log_warning "TypeScript test skipped: dependencies not installed"
        return 0
    fi
    
    # Try to run TypeScript compiler
    (
        cd "$api_dir" || exit 1
        if npm run check:types &>/dev/null; then
            log_success "TypeScript compilation test passed"
            return 0
        else
            log_warning "TypeScript compilation test failed"
            return 1
        fi
    )
}

# =============================================================================
# SETUP ORCHESTRATION
# =============================================================================

# Main setup function
run_setup() {
    log_info "🧪 Starting Lab Development Environment Setup"
    echo
    
    # Phase 1: Environment Validation
    log_info "Phase 1: Environment Validation"
    run_step "VALIDATE_NODEJS" validate_nodejs
    run_step_degraded "CHECK_PORT_CONFLICTS" check_port_conflicts
    run_step "VALIDATE_GIT" validate_git
    run_step "VALIDATE_DIRENV" validate_direnv
    run_step "VALIDATE_DOCKER" validate_docker
    
    # Phase 2: Tool Installation
    log_info "Phase 2: Tool Installation"
    run_step "VALIDATE_OS_AND_TOOLS" validate_os_and_package_manager
    
    # Phase 3: Infrastructure Setup
    log_info "Phase 3: Infrastructure Setup"
    run_step "DOCKER_NETWORK_CREATE" create_docker_network
    run_step "VERDACCIO_SETUP" setup_verdaccio
    
    # Phase 4: Project Dependencies
    log_info "Phase 4: Project Dependencies"
    run_step "DEPENDENCIES_INSTALL" install_dependencies
    
    # Phase 5: Environment Configuration
    log_info "Phase 5: Environment Configuration"
    run_step "DIRENV_SETUP" setup_direnv_environment
    
    # Phase 6: Testing and Validation
    log_info "Phase 6: Testing and Validation"
    run_step_degraded "TEST_VERDACCIO" test_verdaccio_accessibility
    run_step_degraded "TEST_PROTOC" test_protoc_generation
    run_step_degraded "TEST_TYPESCRIPT" test_typescript_compilation
    
    # Mark setup as completed
    run_step "SETUP_COMPLETE" true
    
    # Show setup summary
    show_setup_summary
    
    # Auto-cleanup state file unless --keep-state flag is used
    auto_cleanup_state
}

# =============================================================================
# SETUP COMPLETION AND SUMMARY
# =============================================================================

# Show comprehensive setup summary
show_setup_summary() {
    echo
    log_success "🎉 Lab Development Environment Setup Complete!"
    echo
    
    log_info "📋 Environment Summary:"
    echo
    
    # Tool Status
    echo "🔧 Development Tools:"
    for tool in grpcurl grpcui protoc direnv node npm docker; do
        if command -v "$tool" &>/dev/null; then
            if [ "$tool" = "node" ]; then
                local version
                version=$(node --version)
                echo "  ✅ $tool ($version)"
            else
                echo "  ✅ $tool"
            fi
        else
            echo "  ❌ $tool (not found)"
        fi
    done
    
    echo
    echo "🐳 Services:"
    if docker ps --format "{{.Names}}" | grep -q "verdaccio"; then
        echo "  ✅ Verdaccio Registry (http://localhost:4873)"
    else
        echo "  ❌ Verdaccio Registry (not running)"
    fi
    
    if docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
        echo "  ✅ Docker Network ($NETWORK_NAME)"
    else
        echo "  ❌ Docker Network ($NETWORK_NAME)"
    fi
    
    echo
    echo "📦 Project:"
    if [ -d "$REPO_ROOT/apis/product-api/node_modules" ]; then
        echo "  ✅ Dependencies installed"
    else
        echo "  ❌ Dependencies not installed"
    fi
    
    if [ -f "$REPO_ROOT/.envrc" ]; then
        echo "  ✅ Environment configured (direnv)"
    else
        echo "  ❌ Environment not configured"
    fi
    
    echo
    log_info "🚀 Quick Start:"
    echo "  • Run 'lab status' to check service status"
    echo "  • Run 'lab version' to see tool versions"
    echo "  • Run 'lab cleanup' to stop services"
    echo "  • Use 'lab' command from any subdirectory (after direnv reload)"
    
    echo
    log_info "💡 Next Steps:"
    echo "  • Restart your shell or run: eval \"\$(direnv hook bash)\""
    echo "  • Navigate to any directory in the project and run 'lab status'"
    echo "  • Start developing with the gRPC environment!"
}