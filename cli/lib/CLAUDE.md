# CLI Command Architecture

## Modular Command Pattern

Break down complex shell functions into focused, single-responsibility modules.

### Core Principles

- **Single Responsibility**: Each module handles one specific concern
- **Function Size**: 5-30 lines (decompose if larger)
- **Clear Naming**: `_action_context()` format
- **Dependency Order**: Load utilities first, then functional modules

### Module Structure

```bash
#!/bin/bash
set -Eeuo pipefail
# =============================================================================
# MODULE NAME - PURPOSE
# =============================================================================

# _function_name
# Clear description of what this function does
_function_name() {
    # Implementation (5-30 lines)
}
```

### Main Orchestrator Pattern

```bash
handle_command() {
    _validate_environment
    _setup_workspace
    _discover_targets
    _execute_workflow
    _aggregate_results
}
```

## Best Practices

### Error Handling
- Use `set -Eeuo pipefail` in all modules
- Handle expected failures with `set +e` / `set -e`
- Exit early on validation failures

### Data Flow
- **Return values** for simple data
- **Exported variables** for complex state
- **Files** for large datasets

### Output Isolation
- Functions returning via stdout must redirect log calls to stderr: `log_info "..." >&2`
- Prevents output contamination during command substitution

### Testing
- Test each module independently
- Mock external dependencies
- Verify error conditions

## Refactoring Workflow

1. **Identify Responsibilities** - Map distinct concerns in monolithic function
2. **Extract Modules** - Create one module per responsibility
3. **Create Orchestrator** - Simple coordinator with no business logic
4. **Maintain Integration** - Preserve CLI interface and exports

## When to Apply

Commands that:
- Exceed 100 lines
- Handle multiple responsibilities
- Are difficult to test/debug
- Need frequent modification
- Could benefit from component reuse

This pattern maintains backward compatibility while improving maintainability, testability, and readability.