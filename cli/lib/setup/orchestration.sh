#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# SETUP ORCHESTRATION MODULE
# =============================================================================
# This module contains the main setup workflow and summary functions for the Lab CLI.

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