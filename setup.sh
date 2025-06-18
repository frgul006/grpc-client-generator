#!/bin/bash
set -euo pipefail

# Configuration
CLEANUP_MODE=false
STATUS_MODE=false
VERSION_MODE=false
HELP_MODE=false

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

EXAMPLES:
    ./setup.sh              # Normal setup
    ./setup.sh --status     # Check service status
    ./setup.sh --cleanup    # Stop all services
    ./setup.sh --version    # Show tool versions

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
    NETWORK_NAME="grpc-dev-network"
    if docker network ls | grep -q "$NETWORK_NAME"; then
        echo "• Docker Network ($NETWORK_NAME): ✅ Exists"
    else
        echo "• Docker Network ($NETWORK_NAME): ❌ Missing"
    fi
    
    # Verdaccio service
    if [ -f "registry/docker-compose.yml" ]; then
        (
            cd registry
            if docker compose ps verdaccio | grep -q "Up"; then
                echo "• Verdaccio Registry: ✅ Running (http://localhost:4873)"
            else
                echo "• Verdaccio Registry: ❌ Not running"
            fi
        )
    else
        echo "• Verdaccio Registry: ❌ Configuration not found"
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

# Run validation checks
validate_nodejs
check_port_conflicts  
validate_git

# Check Docker availability
if ! command -v docker &> /dev/null; then
  echo "❌ Docker is required but not installed."
  echo "   Install it from: https://docs.docker.com/get-docker/"
  exit 1
fi

# Check Docker Compose availability
if ! docker compose version &> /dev/null; then
  echo "❌ Docker Compose is required but not available."
  echo "   Make sure Docker Desktop is running or install Docker Compose"
  exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Create Docker network if it doesn't exist
NETWORK_NAME="grpc-dev-network"
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "📡 Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
else
  echo "✅ Docker network '$NETWORK_NAME' already exists"
fi

# Detect OS
OS=$(uname -s)

case "$OS" in
  "Darwin")
    echo "📱 Detected macOS"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew is required but not installed."
      echo "   Install it from: https://brew.sh"
      exit 1
    fi
    
    # Check and install grpcurl
    if ! command -v grpcurl &> /dev/null; then
      echo "📦 Installing grpcurl..."
      brew install grpcurl
    else
      echo "✅ grpcurl is already installed"
    fi
    
    # Check and install grpcui
    if ! command -v grpcui &> /dev/null; then
      echo "📦 Installing grpcui..."
      brew install grpcui
    else
      echo "✅ grpcui is already installed"
    fi
    
    # Check and install protoc
    if ! command -v protoc &> /dev/null; then
      echo "📦 Installing protoc..."
      brew install protobuf
    else
      echo "✅ protoc is already installed"
    fi
    ;;
    
  "Linux")
    echo "🐧 Detected Linux"
    echo "📝 Please install grpcurl, grpcui, and protoc manually:"
    echo "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    echo "   grpcui: https://github.com/fullstorydev/grpcui#installation"
    echo "   protoc: https://grpc.io/docs/protoc-installation/"
    
    # Check if tools are available
    if ! command -v grpcurl &> /dev/null; then
      echo "❌ grpcurl not found - please install it first"
      exit 1
    fi
    
    if ! command -v grpcui &> /dev/null; then
      echo "❌ grpcui not found - please install it first"
      exit 1
    fi
    
    if ! command -v protoc &> /dev/null; then
      echo "❌ protoc not found - please install it first"
      exit 1
    fi
    ;;
    
  *)
    echo "❓ Unsupported OS: $OS"
    echo "📝 Please install grpcurl, grpcui, and protoc manually:"
    echo "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    echo "   grpcui: https://github.com/fullstorydev/grpcui#installation"
    echo "   protoc: https://grpc.io/docs/protoc-installation/"
    exit 1
    ;;
esac

# Setup Verdaccio registry
echo ""
echo "🗃️  Setting up local NPM registry (Verdaccio)..."

(
    cd registry
    
    # Check if Verdaccio is already running
    if docker compose ps verdaccio | grep -q "Up"; then
      echo "✅ Verdaccio registry is already running"
    else
      echo "🚀 Starting Verdaccio registry..."
      docker compose up -d
      
      # Wait for health check
      echo "⏳ Waiting for Verdaccio to be healthy..."
      timeout=60
      counter=0
      while (( counter < timeout )); do
        if docker compose ps verdaccio | grep -q "healthy"; then
          echo "✅ Verdaccio registry is healthy and ready"
          break
        fi
        sleep 2
        counter=$((counter + 2))
      done
      
      if [ $counter -ge $timeout ]; then
        echo "⚠️  Verdaccio took longer than expected to start, but it may still be starting up"
      fi
    fi
)

# Install project dependencies
install_dependencies() {
    log_progress "Installing project dependencies..."
    
    (
        cd apis/product-api
        
        if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
            log_info "Running npm install..."
            if npm install; then
                log_success "Dependencies installed successfully"
            else
                log_error "Failed to install dependencies"
                exit 1
            fi
        else
            log_success "Dependencies already installed"
        fi
    )
}

# Install project dependencies
install_dependencies

# Environment validation and smoke tests
run_smoke_tests() {
    log_progress "Running environment smoke tests..."
    
    # Test 1: Verify Verdaccio is accessible
    log_info "Testing Verdaccio accessibility..."
    if curl -s http://localhost:4873 > /dev/null; then
        log_success "Verdaccio is accessible at http://localhost:4873"
    else
        log_warning "Verdaccio may not be fully ready yet"
    fi
    
    # Test 2: Test protoc code generation
    log_info "Testing protoc code generation..."
    (
        cd apis/product-api
        if output=$(npm run generate 2>&1); then
            log_success "Protoc code generation works"
        else
            log_warning "Protoc code generation failed - check protoc installation"
            printf "${RED}Details:\n%s${NC}\n" "$output"
        fi
    )
    
    # Test 3: TypeScript compilation
    log_info "Testing TypeScript compilation..."
    (
        cd apis/product-api
        if output=$(npm run check:types 2>&1); then
            log_success "TypeScript compilation works"
        else
            log_warning "TypeScript compilation issues detected"
            printf "${RED}Details:\n%s${NC}\n" "$output"
        fi
    )
    
    log_success "Smoke tests completed"
}

# Run smoke tests
run_smoke_tests

echo ""
log_success "✅ Development environment setup complete!"
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
