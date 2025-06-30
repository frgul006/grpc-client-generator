# Context Findings

## Current Implementation Analysis

### 1. Install Dependencies Function
- Location: `cli/lib/setup/infrastructure.sh:68-99`
- Currently hardcoded to only install dependencies for `apis/product-api`
- Uses Verdaccio registry (http://localhost:4873) for npm operations
- Implements retry logic via `retry_with_backoff` function
- Resets npm registry to default after installation (success or failure)

### 2. Package Locations
Found 5 package.json files in the monorepo:
- `/package.json` (root)
- `/apis/product-api/package.json` (API)
- `/apis/user-api/package.json` (API)
- `/libs/grpc-client-generator/package.json` (library)
- `/services/example-service/package.json` (service)

### 3. Retry and Error Handling
- `retry_with_backoff` function in `cli/lib/state/execution.sh:82-107`
- Supports exponential backoff with jitter
- Configuration: MAX_RETRY_ATTEMPTS=3, BASE_RETRY_DELAY=2
- Error handling with checkpoint state tracking

### 4. Logging Infrastructure
- Logging functions in `cli/lib/common.sh`
- Available functions: log_info, log_success, log_warning, log_error, log_progress, log_debug
- All logs include timestamp and colored emoji indicators
- Verbose mode support for debug logging

### 5. State Management
- State file tracking for step completion/failure
- Checkpoint system allows resuming from failed steps
- run_step() function handles step execution with checkpointing

### 6. Setup Orchestration
- Main setup flow in `cli/lib/setup/orchestration.sh:run_setup()`
- Phase 4 specifically calls install_dependencies
- Setup summary shows dependency status (currently only for product-api)

## Similar Patterns in Codebase

### 1. Package Discovery Pattern
The `handle_dev_command` in `cli/lib/commands/handlers.sh:298-404` already discovers packages:
```bash
local packages=()
for dir in apis libs services; do
    if [[ -d "$REPO_ROOT/$dir" ]]; then
        packages+=($(find "$REPO_ROOT/$dir" -mindepth 1 -maxdepth 1 -type d))
    fi
done
```

### 2. Progress Tracking Pattern
The preflight dashboard shows real-time progress across multiple packages, using similar logging patterns.

## Technical Constraints

1. **Verdaccio Registry**: Must maintain npm registry configuration for each package installation
2. **Error Recovery**: Need to handle individual package failures without breaking entire setup
3. **State Tracking**: Should integrate with existing checkpoint system
4. **Directory Structure**: Packages are organized in /apis/*, /libs/*, /services/* directories
5. **Installation Order**: Should respect dependency order (libs before apis/services)

## Integration Points

1. **State File**: Need to create individual checkpoints for each package installation
2. **Summary Display**: Update `show_setup_summary()` to report all package statuses
3. **Logging**: Use existing log functions with package-specific context
4. **Error Handling**: Leverage existing retry_with_backoff mechanism