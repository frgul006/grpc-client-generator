# Ticket-02: Modularize Lab CLI Script

## Epic/Scope

cli-refactor

## What

Break out the massive 1,715-line `/cli/lab` script into smaller, focused modules to improve maintainability, readability, and testability.

## Why

The current `/cli/lab` file has grown to 1,715 lines with mixed concerns including:

- Logging and utilities
- State management and error recovery
- Command parsing and help system
- Setup operations and validation
- Service management

This creates several problems:

- **Maintainability**: Hard to navigate and modify without affecting unrelated functionality
- **Testing**: Difficult to unit test individual components
- **Collaboration**: Merge conflicts more likely with large monolithic file
- **Debugging**: Hard to isolate issues to specific functional areas
- **Code reuse**: Utility functions buried in large script, not easily reusable

## How

### 1. Analyze Current Structure

- Map all functions by category (logging, state, commands, setup, help)
- Identify dependencies between function groups
- Document current function signatures and interfaces

### 2. Create Module Structure

```bash
cli/
├── lab                    # Main entry point (minimal orchestration)
└── lib/
    ├── common.sh         # Common utilities, logging, repo detection
    ├── state.sh          # State management, checkpoints, error recovery
    ├── commands.sh       # Command handlers (setup, status, cleanup, etc.)
    ├── help.sh           # Help system, usage text, command-specific help
    └── setup.sh          # Setup operations, tool installation, validation
```

### 3. Module Breakdown

#### `cli/lib/common.sh`

- Repository detection (`find_repo_root`)
- Logging functions (`log_info`, `log_success`, `log_warning`, `log_error`, `log_debug`)
- Color definitions and utilities
- Configuration variables and constants
- Basic utility functions

#### `cli/lib/state.sh`

- Checkpoint management (`set_checkpoint`, `get_checkpoint`, `clear_checkpoints`)
- State validation (`validate_state_consistency`)
- Error recovery and reporting
- Retry mechanisms with exponential backoff
- Auto-cleanup functionality

#### `cli/lib/commands.sh`

- Command handler functions (`handle_command`)
- Individual command implementations (status, version, cleanup, reset, resume)
- Command validation and routing
- Flag validation (e.g., `--keep-state` only with setup/resume)

#### `cli/lib/help.sh`

- Main help system (`show_help`)
- Command-specific help functions (`show_setup_help`, `show_status_help`, etc.)
- Help routing (`show_command_help`)
- Usage examples and documentation

#### `cli/lib/setup.sh`

- Setup orchestration and main setup logic
- Tool installation and validation functions
- Environment validation (Node.js, Docker, etc.)
- Service management (Docker network, Verdaccio)
- Smoke tests and verification

#### `cli/lab` (Main Entry Point)

- Argument parsing (`parse_args`)
- Module loading and initialization
- High-level coordination
- Error handling and cleanup

### 4. Implementation Steps

1. **Create module directory structure**

   ```bash
   mkdir -p cli/lib
   ```

2. **Extract common utilities first** (least dependencies)

   - Move logging functions to `cli/lib/common.sh`
   - Add sourcing mechanism to main script
   - Test basic functionality

3. **Extract state management** (depends on common)

   - Move checkpoint and error recovery to `cli/lib/state.sh`
   - Update dependencies and test

4. **Extract help system** (depends on common)

   - Move all help functions to `cli/lib/help.sh`
   - Test all help commands and formats

5. **Extract command handlers** (depends on common, state, help)

   - Move command logic to `cli/lib/commands.sh`
   - Test all command executions

6. **Extract setup operations** (depends on all others)

   - Move setup logic to `cli/lib/setup.sh`
   - Test full setup process

7. **Refactor main entry point**
   - Simplify `cli/lab` to minimal orchestration
   - Add proper module loading with error handling
   - Test complete integration

### 5. Module Loading Strategy

```bash
# In cli/lab
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source modules with error handling
source_module() {
    local module="$1"
    if [[ -f "$LIB_DIR/$module" ]]; then
        source "$LIB_DIR/$module" || {
            echo "Error: Failed to load module $module" >&2
            exit 1
        }
    else
        echo "Error: Module $module not found at $LIB_DIR/$module" >&2
        exit 1
    fi
}

# Load modules in dependency order
source_module "common.sh"
source_module "state.sh"
source_module "help.sh"
source_module "commands.sh"
source_module "setup.sh"
```

### 6. Testing Strategy

- **Unit Testing**: Test individual modules in isolation
- **Integration Testing**: Test module interactions
- **Regression Testing**: Ensure all existing functionality works
- **Performance Testing**: Verify no significant performance impact

### 7. Backward Compatibility

- Maintain all existing command-line interfaces
- Preserve all functionality and behavior
- Keep same configuration and state file formats
- Ensure no breaking changes for users

## Definition of Done

### Core Requirements

- [ ] CLI script broken into 5 focused modules (common, state, help, commands, setup)
- [ ] Main `cli/lab` file reduced to < 200 lines (orchestration only)
- [ ] All existing functionality preserved and tested
- [ ] No changes to user-facing CLI interface or behavior

### Module Quality

- [ ] Each module has clear, single responsibility
- [ ] Module dependencies are minimal and well-defined
- [ ] Functions are properly documented with comments
- [ ] No circular dependencies between modules

### Testing & Validation

- [ ] All commands work exactly as before: `lab help`, `lab setup`, `lab status`, etc.
- [ ] Command-specific help works: `lab setup --help`, `lab help status`
- [ ] Error handling and edge cases work: misplaced args, invalid flags
- [ ] State management and recovery work: checkpoints, resume, reset
- [ ] Module loading handles missing files gracefully

### Documentation

- [ ] Module structure documented in comments
- [ ] Function dependencies and interfaces documented
- [ ] Update any relevant documentation about the CLI structure

### Code Quality

- [ ] Each module follows existing code style and conventions
- [ ] Proper error handling in module loading
- [ ] No global variable conflicts between modules
- [ ] Clean separation of concerns

## Priority

**Medium** - Improves maintainability but doesn't block current functionality

## Estimated Effort

**Large** (6-8 hours)

- Analysis and planning: 1 hour
- Module extraction and refactoring: 4-5 hours
- Testing and validation: 2 hours
- Documentation updates: 1 hour

## Risks & Considerations

### Technical Risks

- **Bash sourcing complexity**: Module loading and variable scoping
- **Function dependencies**: Ensuring proper order of operations
- **State management**: Preserving stateful behavior across modules

### Mitigation Strategies

- Implement incremental extraction (one module at a time)
- Comprehensive testing at each step
- Keep backup of working monolithic version
- Document all function interfaces and dependencies

### Success Criteria

- Significantly improved code organization and maintainability
- No regression in functionality or performance
- Easier to add new commands and features
- Better foundation for future CLI enhancements
