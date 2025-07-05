#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# SETUP VALIDATION MODULE
# =============================================================================
# This module contains environment and tool validation functions for the Lab CLI.

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

# Install and configure Git hooks for repository safety
setup_git_hooks() {
    log_debug "Setting up Git hooks for registry safety..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warning "Not in a Git repository, skipping Git hooks setup"
        return 0
    fi
    
    local hooks_source_dir="$REPO_ROOT/.githooks"
    local hooks_target_dir="$REPO_ROOT/.git/hooks"
    
    # Check if .githooks directory exists
    if [ ! -d "$hooks_source_dir" ]; then
        log_warning "No .githooks directory found, skipping Git hooks setup"
        return 0
    fi
    
    # Ensure target directory exists
    mkdir -p "$hooks_target_dir"
    
    # Install hooks from .githooks/ directory
    local hooks_installed=0
    for hook_file in "$hooks_source_dir"/*; do
        if [[ -f "$hook_file" && "$(basename "$hook_file")" != "install.sh" ]]; then
            local hook_name=$(basename "$hook_file")
            log_debug "Installing Git hook: $hook_name"
            
            # Copy and make executable
            cp "$hook_file" "$hooks_target_dir/$hook_name"
            chmod +x "$hooks_target_dir/$hook_name"
            
            hooks_installed=$((hooks_installed + 1))
        fi
    done
    
    if [ $hooks_installed -gt 0 ]; then
        log_success "Git hooks installed ($hooks_installed hook(s))"
        log_info "💡 Pre-commit hook will prevent accidental registry state commits"
    else
        log_info "No Git hooks found to install"
    fi
    
    return 0
}