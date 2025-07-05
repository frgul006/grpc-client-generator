#!/bin/bash
set -Eeuo pipefail
# common.sh - Common utilities, logging, and repository detection

# Colors for enhanced logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Repository path detection
find_repo_root() {
    local current_dir="$(pwd)"
    
    # Look for .git directory or other markers going up the directory tree
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/.git" ] && [ -f "$current_dir/.envrc" ] && [ -d "$current_dir/cli" ]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Not found
    return 1
}

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

log_debug() {
    if [ "$VERBOSE_MODE" = true ]; then
        printf "${CYAN}[%s] 🔍 %s${NC}\n" "$(date '+%H:%M:%S')" "$1"
    fi
}


# Check if Verdaccio is running
check_verdaccio_running() {
    # Check if Docker is available
    if ! command -v docker &>/dev/null; then
        return 1
    fi
    
    # Check if Verdaccio container is running
    local verdaccio_container
    verdaccio_container=$(docker ps --format "{{.Names}}" | grep "verdaccio" | head -n1)
    
    if [ -n "$verdaccio_container" ]; then
        # Verdaccio container is running, check if it's accessible
        if curl -s -o /dev/null -w "%{http_code}" "${VERDACCIO_URL:-http://localhost:4873}" | grep -q "200"; then
            return 0
        fi
    fi
    
    return 1
}

# =============================================================================
# REGISTRY MANAGEMENT FUNCTIONS
# =============================================================================

# Switch to local Verdaccio registry
switch_to_local_registry() {
    log_debug "Switching npm registry to local Verdaccio..."
    npm config set registry "$VERDACCIO_URL"
    log_info "📦 Registry switched to local mode: $VERDACCIO_URL"
}

# Switch back to default npm registry  
switch_to_default_registry() {
    log_debug "Switching npm registry to default..."
    npm config set registry https://registry.npmjs.org/
    log_info "📦 Registry switched to default mode"
}

# Get current registry mode
get_current_registry_mode() {
    local current_registry
    current_registry=$(npm config get registry)
    
    if [[ "$current_registry" == *"localhost:4873"* ]]; then
        echo "local"
    else
        echo "default"
    fi
}

# Check if local registry is active
is_local_registry_active() {
    [[ "$(get_current_registry_mode)" == "local" ]]
}