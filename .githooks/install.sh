#!/bin/bash
set -Eeuo pipefail

# =============================================================================
# GIT HOOKS INSTALLATION SCRIPT
# =============================================================================
# Installs git hooks from .githooks/ directory to .git/hooks/
# Part of Issue #57 Phase 3: Essential Git Safety Mechanisms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SOURCE_DIR="$REPO_ROOT/.githooks"
HOOKS_TARGET_DIR="$REPO_ROOT/.git/hooks"

echo "🔧 Installing git hooks..."

# Ensure target directory exists
mkdir -p "$HOOKS_TARGET_DIR"

# Install each hook from .githooks/ directory
for hook_file in "$HOOKS_SOURCE_DIR"/*; do
    if [[ -f "$hook_file" && "$(basename "$hook_file")" != "install.sh" ]]; then
        hook_name=$(basename "$hook_file")
        echo "  📦 Installing $hook_name..."
        
        # Copy and make executable
        cp "$hook_file" "$HOOKS_TARGET_DIR/$hook_name"
        chmod +x "$HOOKS_TARGET_DIR/$hook_name"
        
        echo "  ✅ $hook_name installed"
    fi
done

echo "🎉 Git hooks installation complete!"
echo ""
echo "📋 Installed hooks:"
ls -la "$HOOKS_TARGET_DIR" | grep -E "^-.*x.*" | awk '{print "  • " $9}' || echo "  • No executable hooks found"
echo ""
echo "💡 These hooks will help prevent accidental commits of registry state during 'lab dev' mode"