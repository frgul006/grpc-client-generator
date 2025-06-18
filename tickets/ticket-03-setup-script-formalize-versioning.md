# Ticket 03: Formalize Versioning

## Epic/Scope
setup-script

## What
Add formal versioning to setup.sh with git-based version tracking, enabling better debugging, support, and deployment tracking through the `--version` flag.

## Why
- **Debugging Support**: Know exactly which version users are running when issues occur
- **Deployment Tracking**: Track which setup version is deployed in different environments
- **Change Management**: Correlate issues with specific script changes
- **User Confidence**: Professional versioning increases trust in the tool
- **Documentation**: Link documentation to specific versions

Currently, when users report issues, it's difficult to know which version of setup.sh they're using, making debugging and support challenging.

## How

### 1. Version Information Strategy
Use git-based versioning combining:
- **Git tag**: Use semantic versioning tags (v1.0.0, v1.1.0, etc.)
- **Git hash**: Show commit hash for exact identification
- **Build date**: When the script was last modified
- **Dirty state**: Indicate if script has uncommitted changes

### 2. Implementation Approach

#### Version Detection Function
```bash
get_version_info() {
    # Get git tag if available, fallback to commit hash
    if git describe --tags --exact-match HEAD 2>/dev/null; then
        VERSION=$(git describe --tags --exact-match HEAD)
    else
        VERSION="dev-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    fi
    
    # Check for dirty working tree
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        DIRTY=""
    else
        DIRTY=" (modified)"
    fi
    
    BUILD_DATE=$(date -r setup.sh '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y setup.sh 2>/dev/null || echo "unknown")
}
```

#### Enhanced --version Output
```
grpc-cli setup script v1.2.0 (commit: abc1234)
Built: 2024-01-15 14:30:22
Git: Clean working tree
```

### 3. Integration Points
- **--version flag**: Show comprehensive version information
- **--status output**: Include version in environment status
- **Error messages**: Include version in error output for support
- **Logging**: Add version to structured log output

### 4. Release Process
- Create git tags for releases using semantic versioning
- Document versioning scheme in README
- Add changelog/release notes process

### 5. Backward Compatibility
- Maintain existing --version flag behavior
- Add new detailed output format
- Ensure script works even without git repository

## Definition of Done

- [ ] `get_version_info()` function accurately detects version information
- [ ] `--version` flag outputs comprehensive version details including:
  - [ ] Version tag or commit hash
  - [ ] Build date
  - [ ] Git working tree status
  - [ ] Script modification date
- [ ] Version information appears in `--status` output
- [ ] Error messages include version for debugging support
- [ ] Script works correctly even when not in git repository
- [ ] Version detection works on both macOS and Linux
- [ ] Documentation updated with versioning scheme
- [ ] Example git tag created (v1.0.0) with proper semantic versioning
- [ ] Changelog template created for future releases

## Priority
Medium

## Estimated Effort
Small (1-2 hours)

## Dependencies
- Git repository (already exists)
- No external dependencies

## Risks
- Git command availability on all platforms
- Performance impact of git commands during script execution
- Complexity of handling non-git environments