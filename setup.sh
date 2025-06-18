#!/bin/bash
set -Eeuo pipefail

# Configuration
CLEANUP_MODE=false
STATUS_MODE=false
VERSION_MODE=false
HELP_MODE=false
RESUME_MODE=false
RESET_MODE=false
KEEP_STATE_MODE=false

# Error recovery configuration
STATE_FILE=".setup_state"
CURRENT_STEP=""
MAX_RETRY_ATTEMPTS=3
BASE_RETRY_DELAY=2
SCRIPT_PID=$$

# Timeout configurations (seconds)
NETWORK_TIMEOUT=30
DOCKER_TIMEOUT=60
VERDACCIO_TIMEOUT=120
TOOL_INSTALL_TIMEOUT=300
NETWORK_NAME="grpc-dev-network"

# Colors for enhanced logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Enhanced logging functions
log_info() {
    printf "${BLUE}[%s] ℹ️  %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
}

log_success() {
    printf "${GREEN}[%s] ✅ %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
}

log_warning() {
    printf "${YELLOW}[%s] ⚠️  %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
}

log_error() {
    printf "${RED}[%s] ❌ %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
}

log_progress() {
    printf "${CYAN}[%s] 🔄 %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
}

# =============================================================================
# ERROR RECOVERY AND STATE MANAGEMENT SYSTEM
# =============================================================================

# Atomic state management functions
set_checkpoint() {
    local step="$1"
    local status="$2"
    local tmp_state_file="${STATE_FILE}.tmp"
    
    # Ensure state file exists
    touch "$STATE_FILE"
    
    # Create new temp file with updated state
    if [ -f "$STATE_FILE" ]; then
        grep -v "^${step}=" "$STATE_FILE" > "$tmp_state_file" 2>/dev/null || true
    fi
    echo "${step}=${status}" >> "$tmp_state_file"
    
    # Atomically replace the old state file
    mv "$tmp_state_file" "$STATE_FILE"
    
    log_info "Checkpoint: $step → $status"
}

get_checkpoint() {
    local step="$1"
    
    if [ ! -f "$STATE_FILE" ]; then
        echo ""
        return
    fi
    
    grep "^${step}=" "$STATE_FILE" 2>/dev/null | tail -n 1 | cut -d'=' -f2 || echo ""
}

clear_checkpoints() {
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "All checkpoints cleared"
    fi
}

# Auto-cleanup state file after successful completion
auto_cleanup_state() {
    if [ "$KEEP_STATE_MODE" = true ]; then
        log_info "State file preserved (--keep-state flag used)"
        return 0
    fi
    
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "Setup state cleaned up automatically (use --keep-state to preserve)"
    fi
}

# Validate state file against actual system state
validate_state_consistency() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1  # No state file to validate
    fi
    
    local inconsistencies=0
    local warnings=()
    
    # Check if state says tools are installed but they're not
    if grep -q "TOOL_GRPCURL_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v grpcurl &>/dev/null; then
            warnings+=("grpcurl marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    if grep -q "TOOL_GRPCUI_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v grpcui &>/dev/null; then
            warnings+=("grpcui marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    if grep -q "TOOL_PROTOC_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! command -v protoc &>/dev/null; then
            warnings+=("protoc marked as installed but not found in PATH")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Check if Docker network state is consistent
    if grep -q "DOCKER_NETWORK_CREATE=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if ! docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$" 2>/dev/null; then
            warnings+=("Docker network marked as created but not found")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Check if dependencies state is consistent
    if grep -q "DEPENDENCIES_INSTALL=COMPLETED" "$STATE_FILE" 2>/dev/null; then
        if [ ! -d "apis/product-api/node_modules" ]; then
            warnings+=("Dependencies marked as installed but node_modules not found")
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
    
    # Report findings
    if [ $inconsistencies -gt 0 ]; then
        log_warning "State file inconsistencies detected:"
        for warning in "${warnings[@]}"; do
            log_warning "  • $warning"
        done
        log_info "Consider running './setup.sh --reset' to start fresh"
        return 1
    fi
    
    return 0
}

# Global error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command_text="$3"
    
    # Mark current step as failed if we're in one
    if [[ -n "$CURRENT_STEP" ]]; then
        set_checkpoint "$CURRENT_STEP" "FAILED"
    fi
    
    log_error "Error on line ${line_number}: command exited with code ${exit_code}"
    log_error "Failing command: ${command_text}"
    
    # Provide recovery suggestion
    log_info "💡 Recovery options:"
    log_info "   • Run './setup.sh --status' to check current state"
    log_info "   • Run './setup.sh --resume' to continue from last checkpoint"
    log_info "   • Run './setup.sh --reset' to start fresh"
    
    exit "$exit_code"
}

handle_interrupt() {
    log_warning "Setup interrupted by user"
    
    # Mark current step as failed if we're in one
    if [[ -n "$CURRENT_STEP" ]]; then
        set_checkpoint "$CURRENT_STEP" "FAILED"
        log_info "Marked step '$CURRENT_STEP' as failed"
    fi
    
    log_info "💡 Use './setup.sh --resume' to continue from last successful step"
    exit 130
}

# Set up global traps
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'handle_interrupt' SIGINT

# Retry mechanism with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        
        # Exponential backoff with jitter
        local delay=$((base_delay * attempt))
        local jitter=$((RANDOM % 3))
        delay=$((delay + jitter))
        
        log_warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}

# Enhanced step execution with checkpointing
run_step() {
    local step_name="$1"
    shift
    local command_to_run=("$@")
    
    local status
    status=$(get_checkpoint "$step_name")
    
    if [[ "$status" == "COMPLETED" ]]; then
        log_success "Skipping step '$step_name': already completed"
        return 0
    fi
    
    log_progress "Starting step: $step_name"
    CURRENT_STEP="$step_name"
    set_checkpoint "$step_name" "IN_PROGRESS"
    
    # Execute the command
    "${command_to_run[@]}"
    
    set_checkpoint "$step_name" "COMPLETED"
    CURRENT_STEP=""
    log_success "Completed step: $step_name"
}

# Enhanced error reporting with context and categorization
report_error() {
    local error_code="$1"
    local component="$2"
    local operation="$3"
    local suggestion="$4"
    local severity="${5:-FATAL}"  # FATAL, RECOVERABLE, DEGRADED
    
    case "$severity" in
        "FATAL")
            log_error "FATAL ERROR $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup cannot continue. Fix this issue and run './setup.sh --resume'"
            ;;
        "RECOVERABLE")
            log_warning "RECOVERABLE ERROR $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup will retry automatically"
            ;;
        "DEGRADED")
            log_warning "NON-CRITICAL ISSUE $error_code in $component during $operation"
            log_info "💡 Suggestion: $suggestion"
            log_info "Setup will continue but functionality may be limited"
            ;;
    esac
    
    log_info "Run './setup.sh --status' to check current state"
}

# Graceful degradation for non-critical operations
run_step_degraded() {
    local step_name="$1"
    shift
    local command_to_run=("$@")
    
    local status
    status=$(get_checkpoint "$step_name")
    
    if [[ "$status" == "COMPLETED" ]]; then
        log_success "Skipping step '$step_name': already completed"
        return 0
    fi
    
    log_progress "Starting optional step: $step_name"
    CURRENT_STEP="$step_name"
    set_checkpoint "$step_name" "IN_PROGRESS"
    
    # Execute the command with degraded error handling
    if "${command_to_run[@]}"; then
        set_checkpoint "$step_name" "COMPLETED"
        CURRENT_STEP=""
        log_success "Completed optional step: $step_name"
        return 0
    else
        set_checkpoint "$step_name" "DEGRADED"
        CURRENT_STEP=""
        log_warning "Optional step '$step_name' failed - continuing setup"
        return 0  # Return success to continue setup
    fi
}

# Progress indicator for long-running operations
show_progress() {
    local message="$1"
    local duration="${2:-30}"
    local interval="${3:-2}"
    
    local counter=0
    local dots=""
    
    while [ $counter -lt $duration ]; do
        dots="${dots}."
        if [ ${#dots} -gt 3 ]; then
            dots="."
        fi
        printf "\r${CYAN}[%s] 🔄 %s%s${NC}" "$(date '+%H:%M:%S')" "$message" "$dots"
        sleep $interval
        counter=$((counter + interval))
    done
    printf "\n"
}

# Enhanced timeout with progress indication
timeout_with_progress() {
    local timeout_seconds="$1"
    local progress_message="$2"
    shift 2
    local command=("$@")
    
    # Run command in background
    "${command[@]}" &
    local cmd_pid=$!
    
    # Show progress while waiting
    local counter=0
    while [ $counter -lt $timeout_seconds ]; do
        if ! kill -0 $cmd_pid 2>/dev/null; then
            # Command finished
            wait $cmd_pid
            return $?
        fi
        
        # Update progress indicator
        local dots=$((counter / 2 % 4))
        local progress_dots=$(printf "%*s" $dots | tr ' ' '.')
        printf "\r${CYAN}[%s] 🔄 %s%s (${counter}s/${timeout_seconds}s)${NC}" \
            "$(date '+%H:%M:%S')" "$progress_message" "$progress_dots"
        
        sleep 2
        counter=$((counter + 2))
    done
    
    # Timeout reached - kill the command
    if kill -0 $cmd_pid 2>/dev/null; then
        kill $cmd_pid 2>/dev/null
        wait $cmd_pid 2>/dev/null
        printf "\n"
        log_warning "Operation timed out after ${timeout_seconds} seconds"
        return 124  # Standard timeout exit code
    fi
}

# =============================================================================
# SPECIALIZED HELPER FUNCTIONS FOR RETRY OPERATIONS
# =============================================================================

# Tool installation with retry and idempotency
install_tool_with_retry() {
    local tool_name="$1"
    local check_command="$2"
    shift 2
    local install_command=("$@")
    
    # Check if tool is already installed
    if bash -c "$check_command" &>/dev/null; then
        log_success "$tool_name is already installed"
        return 0
    fi
    
    log_progress "Installing $tool_name..."
    if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY "${install_command[@]}"; then
        log_success "$tool_name installed successfully"
        return 0
    else
        report_error "TOOL_INSTALL_FAILED" "$tool_name" "installation" "Check network connection and package manager"
        return 1
    fi
}

# Docker operation with retry
docker_operation_with_retry() {
    local operation_name="$1"
    shift
    local docker_command=("$@")
    
    log_progress "Executing Docker operation: $operation_name"
    if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY "${docker_command[@]}"; then
        log_success "Docker operation '$operation_name' completed"
        return 0
    else
        report_error "DOCKER_OPERATION_FAILED" "Docker" "$operation_name" "Check Docker daemon status and network connectivity"
        return 1
    fi
}

# Network operation with timeout
# Safe command execution with validation
safe_execute() {
    local step_name="$1"
    local validation_command="$2"
    shift 2
    local command=("$@")
    
    # Check if already satisfied
    if bash -c "$validation_command" &>/dev/null; then
        log_success "Step '$step_name': already satisfied"
        return 0
    fi
    
    # Execute command
    log_progress "Executing: $step_name"
    "${command[@]}"
    
    # Validate result
    if bash -c "$validation_command" &>/dev/null; then
        log_success "Step '$step_name': completed and validated"
        return 0
    else
        log_error "Step '$step_name': validation failed after execution"
        return 1
    fi
}

# Show help information
show_help() {
    cat << 'EOF'
🚀 gRPC Development Environment Setup

USAGE:
    ./setup.sh [OPTIONS]

OPTIONS:
    --help          Show this help message
    --version       Show version information for all tools
    --status        Show current status of services and tools
    --cleanup       Stop all services and clean up
    --resume        Resume setup from last successful checkpoint
    --reset         Clear all checkpoints and start fresh
    --keep-state    Preserve setup state file after completion

EXAMPLES:
    ./setup.sh              # Normal setup
    ./setup.sh --status     # Check service status
    ./setup.sh --cleanup    # Stop all services
    ./setup.sh --version    # Show tool versions
    ./setup.sh --resume     # Resume from last checkpoint
    ./setup.sh --reset      # Clear checkpoints and start fresh
    ./setup.sh --keep-state # Setup with persistent state file

This script will:
• Install development tools (grpcurl, grpcui, protoc)
• Set up Docker network and Verdaccio registry
• Validate Node.js environment and dependencies
• Run environment smoke tests

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP_MODE=true
                shift
                ;;
            --status)
                STATUS_MODE=true
                shift
                ;;
            --version)
                VERSION_MODE=true
                shift
                ;;
            --help)
                HELP_MODE=true
                shift
                ;;
            --resume)
                RESUME_MODE=true
                shift
                ;;
            --reset)
                RESET_MODE=true
                shift
                ;;
            --keep-state)
                KEEP_STATE_MODE=true
                shift
                ;;
            *)
                log_error "Unknown option: '$1'"
                show_help
                exit 1
                ;;
        esac
    done
}

# Handle different modes
handle_modes() {
    if [ "$HELP_MODE" = true ]; then
        show_help
        exit 0
    fi
    
    if [ "$VERSION_MODE" = true ]; then
        show_versions
        exit 0
    fi
    
    if [ "$STATUS_MODE" = true ]; then
        show_status
        exit 0
    fi
    
    if [ "$CLEANUP_MODE" = true ]; then
        cleanup_services
        exit 0
    fi
    
    if [ "$RESET_MODE" = true ]; then
        clear_checkpoints
        log_info "Setup state reset. Run './setup.sh' to start fresh."
        exit 0
    fi
    
    if [ "$RESUME_MODE" = true ]; then
        if [ ! -f "$STATE_FILE" ]; then
            log_warning "No checkpoint file found. Starting fresh setup."
        else
            log_info "Resuming setup from checkpoints..."
            log_info "Validating checkpoint consistency with actual system state..."
            
            if validate_state_consistency; then
                log_success "State file is consistent with system state"
            else
                log_warning "State file inconsistencies detected (see warnings above)"
                log_info "You can continue anyway, but consider '--reset' for a clean start"
                
                # Give user a chance to cancel
                echo ""
                echo "Continue with potentially inconsistent state? (y/N)"
                if ! read -r -t 10 response || [[ ! "$response" =~ ^[Yy]$ ]]; then
                    log_info "Setup cancelled. Use './setup.sh --reset' to start fresh."
                    exit 0
                fi
            fi
        fi
    fi
}

# Show version information
show_versions() {
    echo "🔧 Tool Versions:"
    echo ""
    
    # Docker versions
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        echo "• Docker: $DOCKER_VERSION"
    else
        echo "• Docker: Not installed"
    fi
    
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        echo "• Docker Compose: $COMPOSE_VERSION"
    else
        echo "• Docker Compose: Not available"
    fi
    
    # Node.js ecosystem
    if command -v node &> /dev/null; then
        NODE_VERSION_DISPLAY=$(node --version)
        echo "• Node.js: $NODE_VERSION_DISPLAY"
    else
        echo "• Node.js: Not installed"
    fi
    
    if command -v npm &> /dev/null; then
        NPM_VERSION_DISPLAY=$(npm --version)
        echo "• npm: v$NPM_VERSION_DISPLAY"
    else
        echo "• npm: Not installed"
    fi
    
    # Development tools
    if command -v grpcurl &> /dev/null; then
        GRPCURL_VERSION=$(grpcurl --version | head -n1)
        echo "• grpcurl: $GRPCURL_VERSION"
    else
        echo "• grpcurl: Not installed"
    fi
    
    if command -v grpcui &> /dev/null; then
        GRPCUI_VERSION=$(grpcui --version | head -n1)
        echo "• grpcui: $GRPCUI_VERSION"
    else
        echo "• grpcui: Not installed"
    fi
    
    if command -v protoc &> /dev/null; then
        PROTOC_VERSION=$(protoc --version)
        echo "• protoc: $PROTOC_VERSION"
    else
        echo "• protoc: Not installed"
    fi
    
    if command -v git &> /dev/null; then
        GIT_VERSION_DISPLAY=$(git --version | awk '{print $3}')
        echo "• Git: $GIT_VERSION_DISPLAY"
    else
        echo "• Git: Not installed"
    fi
    
    echo ""
    check_for_updates
}

# Show service status
show_status() {
    echo "📊 Service Status:"
    echo ""
    
    # Docker network
    local network_name="grpc-dev-network"
    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        echo "• Docker Network ($network_name): ✅ Exists"
    else
        echo "• Docker Network ($network_name): ❌ Missing"
    fi
    
    # Verdaccio service - check both Docker and standalone
    verdaccio_running=false
    verdaccio_type=""
    
    # Check if running in Docker
    if [ -f "registry/docker-compose.yml" ]; then
        (
            cd registry
            if docker compose ps verdaccio | grep -q "Up"; then
                verdaccio_running=true
                verdaccio_type="Docker"
            fi
        )
    fi
    
    # Check if running standalone (via port check)
    if [ "$verdaccio_running" = false ] && command -v lsof &> /dev/null; then
        if lsof -i :4873 &> /dev/null; then
            # Test if it's actually Verdaccio by checking the response
            if curl -s --max-time 2 http://localhost:4873 | grep -q "Verdaccio\|Local NPM Registry" 2>/dev/null; then
                verdaccio_running=true
                verdaccio_type="Standalone"
            fi
        fi
    fi
    
    if [ "$verdaccio_running" = true ]; then
        echo "• Verdaccio Registry: ✅ Running ($verdaccio_type - http://localhost:4873)"
    else
        echo "• Verdaccio Registry: ❌ Not running"
    fi
    
    # Port usage
    echo ""
    echo "🔌 Port Status:"
    if command -v lsof &> /dev/null; then
        if lsof -i :4873 &> /dev/null; then
            PROCESS_4873=$(lsof -i :4873 | awk 'NR>1 {print $1 " (PID " $2 ")"; exit}')
            echo "• Port 4873 (Verdaccio): 🔴 In use by $PROCESS_4873"
        else
            echo "• Port 4873 (Verdaccio): 🟢 Available"
        fi
        
        if lsof -i :50052 &> /dev/null; then
            PROCESS_50052=$(lsof -i :50052 | awk 'NR>1 {print $1 " (PID " $2 ")"; exit}')
            echo "• Port 50052 (gRPC): 🔴 In use by $PROCESS_50052"
        else
            echo "• Port 50052 (gRPC): 🟢 Available"
        fi
    else
        echo "• Port checks: ⚠️ lsof not available"
    fi
    
    # Project dependencies
    echo ""
    echo "📦 Project Status:"
    if [ -d "apis/product-api/node_modules" ]; then
        echo "• Dependencies: ✅ Installed"
    else
        echo "• Dependencies: ❌ Not installed"
    fi
    
    if [ -f "apis/product-api/package.json" ]; then
        echo "• Package.json: ✅ Found"
    else
        echo "• Package.json: ❌ Missing"
    fi
    
    # Development tools validation
    echo ""
    echo "🔧 Development Tools:"
    if command -v grpcurl &> /dev/null; then
        echo "• grpcurl: ✅ Installed"
    else
        echo "• grpcurl: ❌ Not installed"
    fi
    
    if command -v grpcui &> /dev/null; then
        echo "• grpcui: ✅ Installed"
    else
        echo "• grpcui: ❌ Not installed"
    fi
    
    if command -v protoc &> /dev/null; then
        echo "• protoc: ✅ Installed"
    else
        echo "• protoc: ❌ Not installed"
    fi
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo "• Node.js: ✅ $NODE_VERSION"
    else
        echo "• Node.js: ❌ Not installed"
    fi
    
    if command -v docker &> /dev/null; then
        echo "• Docker: ✅ Installed"
    else
        echo "• Docker: ❌ Not installed"
    fi
    
    # Setup progress checkpoints
    echo ""
    echo "🔄 Setup Progress:"
    if [ -f "$STATE_FILE" ]; then
        # Count completed steps using awk for robust counting
        completed=$(awk '/=COMPLETED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
        failed=$(awk '/=FAILED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
        in_progress=$(awk '/=IN_PROGRESS$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
        degraded=$(awk '/=DEGRADED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
        
        echo "• Completed steps: $completed"
        echo "• Failed steps: $failed"
        echo "• In progress: $in_progress"
        echo "• Degraded steps: $degraded"
        
        if [ $failed -gt 0 ] || [ $in_progress -gt 0 ]; then
            echo ""
            echo "💡 Recovery options:"
            echo "   • Run './setup.sh --resume' to continue from last checkpoint"
            echo "   • Run './setup.sh --reset' to clear state and start fresh"
        fi
        
        # Show detailed step status
        echo ""
        echo "📋 Step Details:"
        while IFS='=' read -r step status; do
            if [ -n "$step" ] && [ -n "$status" ]; then
                case "$status" in
                    "COMPLETED")
                        echo "   ✅ $step"
                        ;;
                    "FAILED")
                        echo "   ❌ $step"
                        ;;
                    "IN_PROGRESS")
                        echo "   🔄 $step"
                        ;;
                    "DEGRADED")
                        echo "   ⚠️  $step (degraded - non-critical failure)"
                        ;;
                    *)
                        echo "   ❓ $step ($status)"
                        ;;
                esac
            fi
        done < "$STATE_FILE"
    else
        # State file doesn't exist - check if system appears to be set up
        tools_installed=0
        [ "$(command -v grpcurl)" ] && tools_installed=$((tools_installed + 1))
        [ "$(command -v grpcui)" ] && tools_installed=$((tools_installed + 1))
        [ "$(command -v protoc)" ] && tools_installed=$((tools_installed + 1))
        
        network_exists=0
        docker network ls --format "{{.Name}}" | grep -q "^grpc-dev-network$" && network_exists=1
        
        deps_installed=0
        [ -d "apis/product-api/node_modules" ] && deps_installed=1
        
        if [ $tools_installed -ge 2 ] && [ $network_exists -eq 1 ] && [ $deps_installed -eq 1 ]; then
            echo "• Setup appears complete (state file auto-cleaned)"
            echo "• Run './setup.sh --keep-state' to re-create state tracking"
        else
            echo "• No setup progress recorded"
            echo "• Run './setup.sh' to start setup with checkpointing"
        fi
    fi
}

# Cleanup services
cleanup_services() {
    echo "🧹 Cleaning up services..."
    
    # Stop Verdaccio
    if [ -f "registry/docker-compose.yml" ]; then
        (
            cd registry
            if docker compose ps verdaccio | grep -q "Up"; then
                log_info "Stopping Verdaccio registry..."
                docker compose down
                log_success "Verdaccio stopped"
            else
                log_info "Verdaccio is not running"
            fi
        )
    fi
    
    log_success "Cleanup completed"
}

# Check for tool updates
check_for_updates() {
    echo "🔄 Update Status:"
    
    # Check Homebrew updates (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
        echo "• Run 'brew update && brew upgrade' to update tools"
    fi
    
    # Check npm updates
    if command -v npm &> /dev/null && [ -f "apis/product-api/package.json" ]; then
        (
            cd apis/product-api
            if ! npm outdated --json &> /dev/null; then
                echo "• Run 'npm update' to update Node.js dependencies"
            fi
        )
    fi
    
    echo "• Check https://docs.docker.com/get-docker/ for Docker updates"
}

# Parse arguments
parse_args "$@"

# Handle special modes
handle_modes

log_info "🚀 Setting up gRPC development environment..."

# Validate Node.js environment
validate_nodejs() {
    log_progress "Validating Node.js environment..."
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log_error "Node.js is required but not installed."
        log_info "   Install from: https://nodejs.org/"
        exit 1
    fi
    
    # Check Node.js version (need 14+ for ESM support)
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    
    if [ "$NODE_MAJOR" -lt 14 ]; then
        log_error "Node.js version $NODE_VERSION is too old. Need version 14+ for ESM support."
        log_info "   Current: v$NODE_VERSION"
        log_info "   Required: v14+"
        exit 1
    fi
    
    log_success "Node.js v$NODE_VERSION is installed"
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        log_error "npm is required but not installed."
        log_info "   npm usually comes with Node.js installation"
        exit 1
    fi
    
    NPM_VERSION=$(npm --version)
    log_success "npm v$NPM_VERSION is installed"
    
    # Check if we're in the right directory structure
    if [ ! -f "apis/product-api/package.json" ]; then
        log_error "Expected project structure not found."
        log_info "   Looking for: apis/product-api/package.json"
        log_info "   Current dir: $(pwd)"
        log_info "   Make sure you're running this from the project root"
        exit 1
    fi
    
    log_success "Project structure validated"
}

# Check for port conflicts
check_port_conflicts() {
    log_progress "Checking for port conflicts..."
    
    # Check if lsof is available
    if ! command -v lsof &> /dev/null; then
        log_warning "lsof command not found, skipping port conflict checks"
        log_info "   To enable this check, please install lsof"
        return
    fi
    
    # Check port 4873 (Verdaccio)
    if lsof -i :4873 &> /dev/null; then
        PROCESS_4873=$(lsof -i :4873 | awk 'NR>1 {print $1 " (PID " $2 ")"; exit}')
        log_warning "Port 4873 (Verdaccio) is already in use by: $PROCESS_4873"
        log_info "   You may need to stop the conflicting process"
    else
        log_success "Port 4873 is available"
    fi
    
    # Check port 50052 (gRPC service)
    if lsof -i :50052 &> /dev/null; then
        PROCESS_50052=$(lsof -i :50052 | awk 'NR>1 {print $1 " (PID " $2 ")"; exit}')
        log_warning "Port 50052 (gRPC service) is already in use by: $PROCESS_50052"
        log_info "   This is OK if you already have the service running"
    else
        log_success "Port 50052 is available"
    fi
}

# Validate git environment
validate_git() {
    log_progress "Validating git environment..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_warning "Git is not installed but recommended for development"
        log_info "   Install from: https://git-scm.com/"
        return
    fi
    
    GIT_VERSION=$(git --version | awk '{print $3}')
    log_success "Git v$GIT_VERSION is installed"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        log_warning "Not in a git repository"
        log_info "   Consider initializing git for version control"
        return
    fi
    
    log_success "Git repository detected"
}

# =============================================================================
# MAIN SETUP EXECUTION WITH CHECKPOINTING
# =============================================================================

# Run validation checks with checkpointing
run_step "VALIDATION_NODEJS" validate_nodejs
run_step "VALIDATION_PORTS" check_port_conflicts  
run_step "VALIDATION_GIT" validate_git

# Docker validation with checkpointing
validate_docker() {
    # Check Docker availability
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed."
        log_info "   Install it from: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    # Check Docker Compose availability  
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is required but not available."
        log_info "   Make sure Docker Desktop is running or install Docker Compose"
        return 1
    fi
    
    log_success "Docker and Docker Compose are available"
}

run_step "VALIDATION_DOCKER" validate_docker

# Docker network setup with retry and checkpointing
create_docker_network() {
    # Check if network already exists
    if docker network ls --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
        log_success "Docker network '$NETWORK_NAME' already exists"
        return 0
    fi
    
    # Create network with retry logic
    safe_execute "create-network-$NETWORK_NAME" \
        "docker network ls --format '{{.Name}}' | grep -q '^${NETWORK_NAME}$'" \
        docker network create "$NETWORK_NAME"
}

run_step "DOCKER_NETWORK_CREATE" create_docker_network

# Tool installation with retry and checkpointing
OS=$(uname -s)

# OS-specific tool installation functions
install_tools_macos() {
    log_info "📱 Detected macOS"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is required but not installed."
        log_info "   Install it from: https://brew.sh"
        return 1
    fi
    
    log_success "Homebrew is available"
}

install_tools_linux() {
    log_info "🐧 Detected Linux"
    log_info "📝 Please install grpcurl, grpcui, and protoc manually:"
    log_info "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    log_info "   grpcui: https://github.com/fullstorydev/grpcui#installation"
    log_info "   protoc: https://grpc.io/docs/protoc-installation/"
}

install_tools_unsupported() {
    log_error "❓ Unsupported OS: $OS"
    log_info "📝 Please install grpcurl, grpcui, and protoc manually:"
    log_info "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    log_info "   grpcui: https://github.com/fullstorydev/grpcui#installation" 
    log_info "   protoc: https://grpc.io/docs/protoc-installation/"
    return 1
}

# Validate OS and package manager
validate_os_and_package_manager() {
    case "$OS" in
        "Darwin")
            install_tools_macos
            ;;
        "Linux")
            install_tools_linux
            ;;
        *)
            install_tools_unsupported
            ;;
    esac
}

run_step "VALIDATION_OS_PACKAGE_MANAGER" validate_os_and_package_manager

# Individual tool installation with checkpoints
if [[ "$OS" == "Darwin" ]]; then
    # macOS installations with brew
    run_step "TOOL_GRPCURL_INSTALL" install_tool_with_retry "grpcurl" "command -v grpcurl" brew install grpcurl
    run_step "TOOL_GRPCUI_INSTALL" install_tool_with_retry "grpcui" "command -v grpcui" brew install grpcui
    run_step "TOOL_PROTOC_INSTALL" install_tool_with_retry "protoc" "command -v protoc" brew install protobuf
else
    # Linux/other OS - validation only
    validate_tool_installed() {
        local tool_name="$1"
        local tool_command="$2"
        
        if ! command -v "$tool_command" &> /dev/null; then
            log_error "$tool_name not found - please install it first"
            return 1
        fi
        log_success "$tool_name is installed"
    }
    
    run_step "TOOL_GRPCURL_VALIDATE" validate_tool_installed "grpcurl" "grpcurl"
    run_step "TOOL_GRPCUI_VALIDATE" validate_tool_installed "grpcui" "grpcui"
    run_step "TOOL_PROTOC_VALIDATE" validate_tool_installed "protoc" "protoc"
fi

# Verdaccio registry setup with retry and checkpointing
setup_verdaccio() {
    log_info "🗃️ Setting up local NPM registry (Verdaccio)..."
    
    # Change to registry directory
    if [ ! -d "registry" ]; then
        log_error "Registry directory not found"
        return 1
    fi
    
    (
        cd registry
        
        # Check if Verdaccio is already running
        if docker compose ps verdaccio | grep -q "Up"; then
            log_success "Verdaccio registry is already running"
            return 0
        fi
        
        # Start Verdaccio with retry logic
        log_progress "Starting Verdaccio registry..."
        if ! retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY docker compose up -d; then
            log_error "Failed to start Verdaccio registry"
            return 1
        fi
        
        # Wait for health check with timeout
        log_progress "Waiting for Verdaccio to be healthy..."
        local counter=0
        while (( counter < VERDACCIO_TIMEOUT )); do
            if docker compose ps verdaccio | grep -q "healthy"; then
                log_success "Verdaccio registry is healthy and ready"
                return 0
            fi
            sleep 2
            counter=$((counter + 2))
        done
        
        # Check one more time before failing
        if docker compose ps verdaccio | grep -q "Up"; then
            log_warning "Verdaccio is running but health check timed out"
            log_info "Registry may still be starting up - check status later"
            return 0
        else
            log_error "Verdaccio failed to start within ${VERDACCIO_TIMEOUT} seconds"
            return 1
        fi
    )
}

run_step "VERDACCIO_SETUP" setup_verdaccio

# Project dependencies installation with retry and checkpointing
install_dependencies() {
    log_progress "Installing project dependencies..."
    
    # Check if project directory exists
    if [ ! -f "apis/product-api/package.json" ]; then
        log_error "Project directory apis/product-api/package.json not found"
        return 1
    fi
    
    (
        cd apis/product-api
        
        # Check if dependencies are already installed
        if [ -d "node_modules" ] && [ -f "package-lock.json" ]; then
            log_success "Dependencies already installed"
            return 0
        fi
        
        # Install dependencies with retry logic
        log_progress "Running npm install..."
        if retry_with_backoff $MAX_RETRY_ATTEMPTS $BASE_RETRY_DELAY npm install; then
            log_success "Dependencies installed successfully"
            
            # Verify installation
            if [ -d "node_modules" ]; then
                log_success "Dependencies verified successfully"
                return 0
            else
                log_error "Dependencies installation verification failed"
                return 1
            fi
        else
            log_error "Failed to install dependencies after $MAX_RETRY_ATTEMPTS attempts"
            return 1
        fi
    )
}

run_step "DEPENDENCIES_INSTALL" install_dependencies

# Environment validation and smoke tests with checkpointing
test_verdaccio_accessibility() {
    log_info "Testing Verdaccio accessibility..."
    
    # Test with timeout using curl's built-in timeout feature
    if curl --max-time $NETWORK_TIMEOUT -s http://localhost:4873 > /dev/null; then
        log_success "Verdaccio is accessible at http://localhost:4873"
        return 0
    else
        log_warning "Verdaccio may not be fully ready yet (or timed out after ${NETWORK_TIMEOUT}s)"
        # This is a non-critical test, so return 0 to continue
        return 0
    fi
}

test_protoc_generation() {
    log_info "Testing protoc code generation..."
    
    (
        cd apis/product-api
        if output=$(npm run generate 2>&1); then
            log_success "Protoc code generation works"
            return 0
        else
            log_warning "Protoc code generation failed - check protoc installation"
            printf "${RED}Details:\n%s${NC}\n" "$output"
            # Non-critical test - continue setup
            return 0
        fi
    )
}

test_typescript_compilation() {
    log_info "Testing TypeScript compilation..."
    
    (
        cd apis/product-api
        if output=$(npm run check:types 2>&1); then
            log_success "TypeScript compilation works"
            return 0
        else
            log_warning "TypeScript compilation issues detected"
            printf "${RED}Details:\n%s${NC}\n" "$output"
            # Non-critical test - continue setup
            return 0
        fi
    )
}

# Run individual smoke tests with graceful degradation
run_step_degraded "TEST_VERDACCIO_ACCESS" test_verdaccio_accessibility
run_step_degraded "TEST_PROTOC_GENERATION" test_protoc_generation
run_step_degraded "TEST_TYPESCRIPT_COMPILATION" test_typescript_compilation

# Mark setup as fully completed
run_step "SETUP_COMPLETE" true

# Auto-cleanup state file unless --keep-state flag is used
auto_cleanup_state

# Comprehensive setup summary and recovery recommendations
show_setup_summary() {
    echo ""
    echo "📊 Setup Summary:"
    echo "=================="
    
    if [ ! -f "$STATE_FILE" ]; then
        log_info "No checkpoint data available"
        return
    fi
    
    # Count different step states using awk for robust counting
    completed=$(awk '/=COMPLETED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
    failed=$(awk '/=FAILED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
    degraded=$(awk '/=DEGRADED$/ {count++} END {print count+0}' "$STATE_FILE" 2>/dev/null)
    local total_steps=$((completed + failed + degraded))
    
    if [ $total_steps -gt 0 ]; then
        local success_rate=$((completed * 100 / total_steps))
        echo "• Total steps: $total_steps"
        echo "• Success rate: ${success_rate}% ($completed completed, $failed failed, $degraded degraded)"
        
        # Show overall status
        if [ $failed -eq 0 ] && [ $degraded -eq 0 ]; then
            log_success "🎉 Perfect setup - all components working optimally!"
        elif [ $failed -eq 0 ]; then
            log_success "✅ Setup completed successfully with minor issues"
            log_warning "⚠️  Some non-critical components have degraded functionality"
        else
            log_warning "⚠️  Setup completed with some failures"
        fi
        
        # Recovery recommendations for degraded components
        if [ $degraded -gt 0 ]; then
            echo ""
            echo "🔧 Recovery Recommendations for Degraded Components:"
            grep "=DEGRADED$" "$STATE_FILE" 2>/dev/null | while IFS='=' read -r step status; do
                case "$step" in
                    "TEST_VERDACCIO_ACCESS")
                        echo "• Verdaccio accessibility: Check if registry is running with 'docker compose ps' in registry/"
                        ;;
                    "TEST_PROTOC_GENERATION")
                        echo "• Protoc generation: Verify protoc installation and proto files syntax"
                        ;;
                    "TEST_TYPESCRIPT_COMPILATION")
                        echo "• TypeScript compilation: Check for type errors with 'npm run check:types'"
                        ;;
                    *)
                        echo "• $step: Run './setup.sh --status' for details"
                        ;;
                esac
            done
        fi
        
        # Show failed components
        if [ $failed -gt 0 ]; then
            echo ""
            echo "❌ Failed Components Requiring Attention:"
            grep "=FAILED$" "$STATE_FILE" 2>/dev/null | while IFS='=' read -r step status; do
                echo "• $step: Run './setup.sh --resume' after fixing prerequisites"
            done
        fi
    fi
    
    echo ""
}

show_setup_summary

echo ""
log_success "Development environment setup complete!"
echo ""
echo "🔧 Available tools:"
echo "   • grpcurl: $(which grpcurl)"
echo "   • grpcui: $(which grpcui)"  
echo "   • protoc: $(which protoc)"
echo "   • Verdaccio registry: http://localhost:4873"
echo ""
echo "💡 To test a gRPC service:"
echo "   grpcurl -plaintext localhost:50052 list"
echo "   grpcui -plaintext localhost:50052"
echo ""
echo "📦 To use the local NPM registry:"
echo "   npm config set registry http://localhost:4873"
echo "   npm config get registry"
echo ""
echo "ℹ️  Additional commands:"
echo "   ./setup.sh --status     # Check service status"
echo "   ./setup.sh --version    # Show tool versions"
echo "   ./setup.sh --cleanup    # Stop all services"
echo "   ./setup.sh --help       # Show detailed help"
