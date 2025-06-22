# Implement `lab dev` Command for Monorepo Development Orchestration

## Problem

The monorepo requires a unified development experience that automatically manages:

- Running `npm run dev` for all packages under `/apis`, `/libs`, and `/services`
- Watching library files for changes and auto-publishing them
- Restarting dependent services when libraries are updated

Currently, developers must manually manage multiple terminal windows and coordinate restarts when libraries change.

## Solution

Implement a `lab dev` command that orchestrates the full development workflow using `concurrently` for process management and `chokidar-cli` for file watching.

### Key Architectural Insight

The existing `lab publish` command already updates dependent packages' `package.json` files, which triggers `nodemon` to automatically restart services. This eliminates the need for complex manual process restart logic.

_Note: This relies on services' `npm run dev` scripts being configured to use `nodemon` or a similar file-watching/restarting mechanism._

**Event Flow:**

1. File change in `/libs` → 2. `lab publish <library>` → 3. Dependent `package.json` updated → 4. `nodemon` auto-restarts services

_Note: This needs to be debounced since we need to wait for the dev command for the lib to finish building the new output before we proceed to step 2._

## Implementation Plan

### Phase 1: Foundation & Basic Parallel Execution

**Goal:** Establish basic infrastructure and parallel dev server execution.

#### Task 1.1: Add Root Dependencies

- **Action:** Create root `package.json` with required dev dependencies
- **Dependencies:** `concurrently`, `chokidar-cli`
- **System Prerequisites:** `jq` (for JSON parsing)
- **Location:** `/package.json`
- **Code:**

  ```json
  {
    "name": "grpc-experiment-monorepo",
    "private": true,
    "devDependencies": {
      "concurrently": "8.2.2", <- or whatever is the latest
      "chokidar-cli": "3.0.0" <- or whatever is the latest
    }
  }
  ```

#### Task 1.2: Extend Setup Command

- **Action:** Add `npm install` to `lab setup` command
- **Location:** `cli/lib/setup.sh` (or integrate into existing setup logic)
- **Purpose:** Ensure dev dependencies are available before `lab dev` runs

#### Task 1.3: Extend CLI Command System

- **Action:** Add `dev` command support to argument parser
- **Location:** `cli/lib/commands.sh`
- **Changes:**
  - Add `dev` to valid commands list
  - Add `handle_dev_command()` function
  - Add help text for `lab dev`

#### Task 1.4: Basic Parallel Execution

- **Action:** Implement basic `lab dev` that runs all dev commands in parallel
- **Location:** `cli/lib/commands.sh`
- **Implementation:**

  ```bash
  handle_dev_command() {
      log_info "🚀 Starting all development servers..."

      # Discover packages with dev scripts
      local packages=()
      for dir in apis libs services; do
          if [[ -d "$REPO_ROOT/$dir" ]]; then
              packages+=($(find "$REPO_ROOT/$dir" -mindepth 1 -maxdepth 1 -type d))
          fi
      done

      # Build concurrently command arguments
      local commands=()
      local names=()
      for pkg in "${packages[@]}"; do
          if [[ -f "$pkg/package.json" ]] && jq -e '.scripts.dev' "$pkg/package.json" >/dev/null 2>&1; then
              local pkg_name=$(basename "$pkg")
              commands+=("npm run dev --prefix $pkg")
              names+=("$pkg_name")
          fi
      done

      if [[ ${#commands[@]} -eq 0 ]]; then
          log_error "No packages with dev scripts found"
          return 1
      fi

      # Run with proper signal handling
      trap 'echo "Shutting down all processes..."; kill 0' SIGINT SIGTERM

      npx concurrently \
          --names "$(IFS=','; echo "${names[*]}")" \
          --prefix-colors "auto" \
          --kill-others-on-fail \
          "${commands[@]}"
  }
  ```

### Phase 2: File Watching & Auto-Publish

**Goal:** Add intelligent file watching that triggers library publishing.

#### Task 2.1: Create Watch Handler Directory

- **Action:** Create `.lab/scripts/` directory structure
- **Location:** `/.lab/scripts/handle-lib-change.sh`

#### Task 2.2: Implement Change Handler Script

- **Action:** Create debounced change handler with lock mechanism
- **Location:** `/.lab/scripts/handle-lib-change.sh`
- **Implementation:**

  ```bash
  #!/bin/bash
  set -Eeuo pipefail

  CHANGED_PATH="$1"
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # Source common utilities
  source "$REPO_ROOT/cli/lib/common.sh"

  # Extract library directory from path
  LIB_DIR=$(echo "$CHANGED_PATH" | grep -o 'libs/[^/]*' | head -n 1)

  if [[ -z "$LIB_DIR" ]]; then
      log_error "[Watcher] Could not determine library from path: $CHANGED_PATH"
      exit 1
  fi

  # Lock mechanism to prevent concurrent publishes
  LOCKFILE="/tmp/lab-publish-$(basename "$LIB_DIR").lock"

  if (set -o noclobber; echo "$$" > "$LOCKFILE") 2>/dev/null; then
      trap 'rm -f "$LOCKFILE"; exit $?' INT TERM EXIT

      log_info "[Watcher] Change detected in $LIB_DIR. Publishing..."

      # Use existing lab publish command
      if "$REPO_ROOT/cli/lab" publish "$(basename "$LIB_DIR")"; then
          log_success "[Watcher] Successfully published $(basename "$LIB_DIR")"
      else
          log_error "[Watcher] Failed to publish $(basename "$LIB_DIR")"
      fi

      rm -f "$LOCKFILE"
      trap - INT TERM EXIT
  else
      log_info "[Watcher] Publish already in progress for $(basename "$LIB_DIR"). Skipping."
  fi
  ```

#### Task 2.3: Integrate File Watcher

- **Action:** Add chokidar watcher to `handle_dev_command()`
- **Location:** `cli/lib/commands.sh`
- **Implementation:**

  ```bash
  # Add to handle_dev_command() after basic setup

  # Start file watcher in background
  log_info "👀 Starting file watcher for libraries..."
  # Note: --initial flag omitted to avoid publishing all libraries on startup
  # Only changes after startup will trigger publishes
  npx chokidar 'libs/**/*.{ts,js,json}' \
      --ignore 'libs/**/node_modules/**' \
      --ignore 'libs/**/dist/**' \
      --ignore 'libs/**/lib/**' \
      --debounce 1000 \
      -c './.lab/scripts/handle-lib-change.sh {path}' \
      > .lab/watcher.log 2>&1 &

  WATCHER_PID=$!

  # Update trap to kill both processes
  trap 'echo "Shutting down all processes..."; kill $WATCHER_PID 2>/dev/null; kill 0' SIGINT SIGTERM
  ```

### Phase 3: Process Management & Polish

**Goal:** Add robust error handling, logging, and user experience improvements.

#### Task 3.1: Enhanced Signal Handling

- **Action:** Implement comprehensive process cleanup
- **Location:** `cli/lib/commands.sh`
- **Features:**
  - Graceful shutdown of all child processes
  - Cleanup of temporary files and locks
  - Status reporting on exit

#### Task 3.2: Error Recovery & Logging

- **Action:** Add robust error handling and logging
- **Features:**
  - Failed publish recovery strategies
  - Service crash handling options
  - Structured logging with timestamps
  - Log file management

#### Task 3.3: Help Integration

- **Action:** Add comprehensive help text
- **Location:** `cli/lib/help.sh`
- **Content:**

  ```bash
  show_dev_help() {
      cat << 'EOF'
  Usage: lab dev [options]

  Start all development servers and watch for library changes.

  This command will:
  • Run 'npm run dev' for all packages in /apis, /libs, and /services
  • Watch library files for changes and auto-publish updates
  • Automatically restart dependent services when libraries change

  Options:
    --verbose     Show detailed output from all processes
    --no-watch    Skip file watching (only run dev servers)

  Examples:
    lab dev              # Start all dev servers with file watching
    lab dev --verbose    # Start with detailed logging
    lab dev --no-watch   # Start servers without file watching

  Notes:
  • Use Ctrl+C to stop all processes
  • Logs are written to .lab/watcher.log
  • Each service output is prefixed with its package name
  EOF
  }
  ```

#### Task 3.4: Integration Testing

- **Action:** Create test scenarios for the full workflow
- **Test Cases:**
  - Library change triggers correct publish
  - Dependent services restart automatically
  - Signal handling works correctly
  - Error recovery functions properly
  - No zombie processes remain after exit

## Risk Analysis & Mitigation

### High Risk: Event Storms

- **Problem:** Multiple file saves trigger rapid `lab publish` calls
- **Mitigation:**
  - Use `--debounce 1000` in chokidar
  - Lock mechanism in change handler
  - Ignore `node_modules`, `dist`, `lib` directories

### High Risk: Process Cleanup

- **Problem:** Zombie processes if not properly terminated
- **Mitigation:**
  - Comprehensive `trap` handling
  - `kill 0` for process groups
  - Test cleanup thoroughly across platforms

### Medium Risk: Circular Triggers

- **Problem:** `lab publish` changes trigger more file watches
- **Mitigation:**
  - Careful ignore patterns in chokidar
  - Ensure `lab publish` doesn't modify source files
  - Monitor for infinite loops in testing

### Medium Risk: Dependency Graph Errors

- **Problem:** `lab publish` fails if dependency resolution breaks
- **Mitigation:**
  - Validate existing `find_dependent_packages` function
  - Add error handling for malformed package.json files
  - Test with various dependency scenarios

### Low Risk: Cross-Platform Compatibility

- **Problem:** Different behavior on macOS vs Linux
- **Mitigation:**
  - Use `chokidar-cli` which handles platform differences
  - Test on multiple platforms
  - Use portable shell constructs

## Success Criteria

- ✅ Single `lab dev` command starts all development servers
- ✅ Library changes automatically trigger publishing and dependent restarts
- ✅ Clean, prefixed output from all services
- ✅ Graceful shutdown with Ctrl+C leaves no zombie processes
- ✅ Robust error handling and recovery
- ✅ Integration with existing bash CLI patterns
- ✅ Comprehensive help documentation
- ✅ No performance degradation with file watching

## Testing Strategy

### Unit Testing

- Individual functions (package discovery, dependency detection)
- Change handler script with various file paths
- Lock mechanism behavior

### Integration Testing

- Full workflow: change → publish → restart
- Error scenarios: failed publishes, missing packages
- Signal handling and process cleanup

### Performance Testing

- Large numbers of simultaneous file changes
- Memory usage with long-running processes
- File watcher performance with large codebases

## Location References

- `cli/lib/commands.sh:104-160` - Command handler functions
- `cli/lib/publish.sh:56-73` - Existing dependency discovery
- `cli/lib/common.sh` - Logging and utility functions
- `/.lab/scripts/` - New handler scripts directory
- `/package.json` - Root dependencies (new file)
