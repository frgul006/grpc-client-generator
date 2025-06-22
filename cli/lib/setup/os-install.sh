#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# OS-SPECIFIC INSTALLATION MODULE
# =============================================================================
# This module contains OS-specific tool installation logic for the Lab CLI.

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