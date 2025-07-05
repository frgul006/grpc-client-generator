# Preflight Module Architecture

## Overview

This module demonstrates a **modular command architecture pattern** that breaks down complex shell functions into focused, single-responsibility modules. The preflight command was refactored from a 239-line monolith into 6 focused modules, each handling a specific aspect of the verification workflow.

## Modular Architecture Pattern

### Core Principle: Single Responsibility
Each module handles one specific concern:

- **environment.sh**: Environment validation & dependency checks
- **workspace.sh**: Temporary directory & output mode setup  
- **discovery.sh**: Package discovery & verification script detection
- **staging.sh**: Producer/consumer classification & monitoring setup
- **execution.sh**: Sequential/parallel execution coordination
- **aggregation.sh**: Results collection & summary reporting
- **index.sh**: Main orchestrator (20 lines max)

### Function Guidelines

**Ideal Function Size**: 5-30 lines
- Functions over 30 lines should be decomposed
- Functions under 5 lines may indicate over-decomposition
- Focus on **single responsibility** over line count

**Function Naming Convention**:
```bash
_validate_preflight_environment()    # Clear action + context
_setup_preflight_workspace()         # Clear action + return value
_discover_verification_packages()    # Clear action + return type
```

### Module Structure Template

```bash
#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# MODULE NAME - PURPOSE
# =============================================================================
# Brief description of module responsibility

# =============================================================================
# SECTION NAME
# =============================================================================

# _function_name
# Clear description of what this function does
# Args: parameter descriptions
# Returns: return value description
_function_name() {
    # Implementation (5-30 lines)
}
```

## Integration Standards

### Module Loading Order
```bash
# Load utility modules first
source "${PREFLIGHT_DIR}/output-mode.sh"
source "${PREFLIGHT_DIR}/phase-tracker.sh"
source "${PREFLIGHT_DIR}/dashboard.sh"

# Load functional modules in dependency order
source "${PREFLIGHT_DIR}/environment.sh"
source "${PREFLIGHT_DIR}/workspace.sh"
source "${PREFLIGHT_DIR}/discovery.sh"
source "${PREFLIGHT_DIR}/staging.sh"
source "${PREFLIGHT_DIR}/execution.sh"
source "${PREFLIGHT_DIR}/aggregation.sh"
```

### Main Orchestrator Pattern
The main function should be a **workflow coordinator**, not an implementer:

```bash
handle_preflight_command() {
    _validate_preflight_environment
    local temp_dir=$(_setup_preflight_workspace)
    local packages=($(_discover_verification_packages))
    _stage_packages_by_role "$temp_dir" "${packages[@]}"
    _execute_staged_verification "$temp_dir"
    _aggregate_verification_results "$temp_dir"
}
```

### Data Flow Between Modules
- Use **return values** for simple data (temp directories, package lists)
- Use **exported variables** for complex state (PREFLIGHT_PRODUCERS, DASHBOARD_MODE)
- Avoid global variables where possible

## Best Practices

### Error Handling
- Maintain `set -Eeuo pipefail` in all modules
- Handle expected failures explicitly with `set +e` / `set -e`
- Exit early on validation failures

### Testing Strategy
- Each module can be tested independently
- Mock external dependencies (jq, npm, file system)
- Test error conditions as well as happy paths

### Backward Compatibility
- Maintain all existing function exports
- Preserve exact same CLI interface
- Keep same exit codes and error messages

## Refactoring Template

When refactoring complex commands, follow this pattern:

### 1. Identify Responsibilities
Map out the distinct concerns in the monolithic function:
- What environment setup is needed?
- What data discovery/processing occurs?
- What execution patterns are used?
- How are results collected and reported?

### 2. Extract Modules
Create one module per responsibility:
- Start with utilities and dependencies
- Extract in dependency order
- Keep functions focused and small

### 3. Create Orchestrator
Write a simple coordinator that calls module functions in sequence:
- No business logic in the orchestrator
- Clear workflow steps
- Proper error handling between steps

### 4. Maintain Integration
- Update module loading in CLI
- Preserve all existing exports
- Test thoroughly before committing

## Example Usage

This pattern is ideal for commands that:
- Have grown beyond 100 lines
- Handle multiple distinct responsibilities  
- Are difficult to test or debug
- Need modification frequently
- Could benefit from component reuse

The refactored preflight command demonstrates how to maintain full backward compatibility while dramatically improving maintainability, testability, and readability.