#!/bin/bash
set -Eeuo pipefail

# =============================================================================
# LIBRARY CHANGE HANDLER
# =============================================================================
# This script handles file changes in library directories by triggering
# republishing using the existing lab publish command.
# 
# Expert analysis improvements:
# - Robust package discovery using Node.js
# - Lock mechanism to prevent concurrent publishes
# - Proper error handling and cleanup

CHANGED_FILE="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source common utilities for logging
source "$REPO_ROOT/cli/lib/common.sh"

# Traverse up the directory tree to find the package.json for the changed file
find_package_json() {
    local current_dir
    current_dir=$(dirname "$CHANGED_FILE")
    
    while [[ "$current_dir" != "." && "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/package.json" ]]; then
            echo "$current_dir/package.json"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done
    
    return 1
}

# Main execution
main() {
    # Find the package.json for the changed file
    local package_json_path
    if ! package_json_path=$(find_package_json); then
        log_error "[Watcher] Could not find a package.json for changed file: $CHANGED_FILE"
        exit 1
    fi
    
    # Use Node.js to parse package.json (no new dependencies needed)
    local package_name
    if ! package_name=$(node -p "
        try {
            require('$REPO_ROOT/$package_json_path').name;
        } catch (e) {
            process.exit(1);
        }
    " 2>/dev/null); then
        log_error "[Watcher] Could not read package name from $package_json_path"
        exit 1
    fi
    
    if [[ -z "$package_name" || "$package_name" == "null" ]]; then
        log_error "[Watcher] Invalid package name from $package_json_path"
        exit 1
    fi
    
    # Lock mechanism to prevent concurrent publishes (project-scoped)
    local lockfile_dir="$REPO_ROOT/.lab/locks"
    mkdir -p "$lockfile_dir"
    local lockfile="$lockfile_dir/publish-$(echo "$package_name" | tr '/' '-').lock"
    
    # Check for stale lock files and clean them up
    if [[ -f "$lockfile" ]]; then
        local lock_pid
        lock_pid=$(cat "$lockfile" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            log_info "[Watcher] 🧹 Cleaning up stale lock file (PID $lock_pid no longer exists)"
            rm -f "$lockfile"
        fi
    fi
    
    # Use noclobber to atomically create lockfile
    if (set -o noclobber; echo "$$" > "$lockfile") 2>/dev/null; then
        # Set up cleanup trap that preserves original exit code
        trap 'rm -f "$lockfile"' INT TERM EXIT
        
        log_info "[Watcher] 📁 Change detected in '$package_name'. Publishing..."
        
        # Use existing lab publish command
        if ! "$REPO_ROOT/cli/lab" publish "$(basename "$package_name")"; then
            local exit_code=$?
            log_error "[Watcher] ❌ Failed to publish '$package_name' (exit code: $exit_code)"
            exit $exit_code
        fi
        
        log_success "[Watcher] ✅ Successfully published '$package_name'"
        # EXIT trap will handle cleanup automatically
    else
        log_info "[Watcher] 🔒 Publish already in progress for '$package_name'. Skipping."
    fi
}

# Execute main function
main "$@"