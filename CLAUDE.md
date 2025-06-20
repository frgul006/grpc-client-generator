# CLAUDE.md

## Behavior

Be brutally honest, don't be a yes man.
If I am wrong, point it out bluntly.
I need honest feedback on my code.

## Code style

- Use ES modules (import/export) syntax
- Destructure imports when possible: `import { Logger } from './logger'`
- TypeScript strict mode enabled - all types must be explicit
- Use type aliases over interfaces for object shapes
- Prefer `const` over `let`, never use `var`
- Test names: use descriptive phrases, avoid "should"
- **FORBIDDEN**: Using `any` is strictly forbidden

### Shell Scripting Guidelines

- Use `set -Eeuo pipefail` for strict error handling in all scripts
- Use `sleep` instead of `timeout` command (timeout doesn't work as expected on macOS)
- Source modules in dependency order (utilities first, then dependent modules)
- Initialize variables after all modules are loaded
- Use `"$variable"` quoting for all variable expansions
- Use `mktemp -d` for temporary directories, always clean up with `rm -rf`
- For modular scripts, use initialization functions rather than inline variable assignment

## Rules

- Always test package.json scripts after adding them
- Don't use "should" in test names
- **CRITICAL**: Create TodoWrite items for documentation updates to ensure they're not forgotten
- **MANDATORY**: ALWAYS run `lab preflight` before running mcp**zen**precommit - this is CRITICAL
- **MANDATORY**: NEVER create git commits without using mcp**zen**precommit first
- **MANDATORY**: Always run mcp**zen**precommit before claiming any coding task is "done" or "complete"
- **MANDATORY**: When precommit identifies test failures or warnings, validate that tests use the exact same commands as real workflows
- **MANDATORY**: Never accept "degraded" test results without verifying the test actually works - run the test commands manually to confirm
- **CRITICAL**: Test functions must use identical commands to the real workflows they validate
- **CRITICAL**: Before committing, manually verify test commands work by running them in the actual environment
- **CRITICAL**: Test function parameters (flags, options, paths) must exactly match production usage
- Progress documentation is MANDATORY - the user will verify this was done
- Use zen and context7 tools for complex technical challenges

## Ticketing System

When you identify improvements that would be scope creep for the current task, create a proposal ticket.

### When to Create a Ticket

Create a ticket ONLY if the improvement:

- Is outside current task scope (would be scope creep)
- Is non-trivial (more than a simple fix, affects multiple lines/files)
- Adds clear value (maintainability, performance, security, or developer experience)

### How to Create a Proposal Ticket

1. **Check for duplicates**: Quick scan of `/tickets/proposals/` filenames
2. **File naming**: `YYYY-MM-DD-brief-description.md` (e.g., `2024-10-27-refactor-auth-logic.md`) - use kebab-case for description
3. **Location**: Create in `/tickets/proposals/` (create directory if missing)
4. **Content format**:

   ```markdown
   # Brief descriptive title

   ## Problem

   Briefly describe the issue or opportunity (1-2 sentences).

   ## Solution

   Brief description of the proposed change.

   ## Location

   - `path/to/file.js:L10-L25` (relative to repository root)
   - `path/to/another.py:L102` (relative to repository root)
   ```

### Important Notes

- Keep proposals concise - detailed planning happens if/when humans activate the ticket
- You only create proposals; humans handle grooming, prioritization, and moving to done
- Never edit existing tickets or move tickets between directories

## Enhanced AI Capabilities: Zen and Context7

## Zen Tools (mcp**zen**\*)

**Deep thinking and analysis tools:**

- **`mcp__zen__thinkdeep`** - Extended reasoning for architecture decisions, complex bugs
- **`mcp__zen__codereview`** - Professional code review with security, quality analysis
- **`mcp__zen__debug`** - Expert debugging for complex issues with 1M token capacity
- **`mcp__zen__analyze`** - General-purpose code and file analysis
- **`mcp__zen__chat`** - Collaborative thinking partner for brainstorming
- **`mcp__zen__precommit`** - Comprehensive pre-commit validation (ALWAYS use before commits)
- **`mcp__zen__testgen`** - Comprehensive test generation with edge case coverage
- **`mcp__zen__refactor`** - Intelligent refactoring with precise line-number guidance

**When to use Zen tools:**

- Complex technical decisions requiring deep analysis
- Debugging challenging issues that need expert insight
- Architecture planning and validation
- Code review before important commits
- When you need a thinking partner for complex problems

### Context7 Tools (mcp**context7**\*)

**Up-to-date documentation and library research:**

- **`mcp__context7__resolve-library-id`** - Find Context7-compatible library IDs
- **`mcp__context7__get-library-docs`** - Fetch current documentation for libraries

**When to use Context7:**

- Need current documentation for libraries/frameworks
- Looking for best practices and examples
- Researching how to use specific tools
- When web search isn't sufficient for technical details

## Systematic Debugging for Shell Scripts

When shell scripts fail, follow this debugging methodology:

### Variable Scoping Issues

1. Check if variables are defined before use with `set -u` enabled
2. Verify sourcing order - variables must be defined before modules that use them
3. Use `declare -p VARIABLE_NAME` to check if variables exist and their values
4. For modular scripts, ensure initialization functions are called after dependencies are loaded

### Module Dependencies

1. Map out which modules depend on which variables/functions
2. Source modules in dependency order (common utilities first, then dependent modules)
3. Initialize variables after all modules are loaded but before functions are called
4. Use initialization functions rather than inline variable assignment in sourced files

### Common Patterns

- **REPO_ROOT issues**: Always set REPO_ROOT before sourcing modules that use it
- **Function not found**: Check if the module containing the function was actually sourced
- **Unbound variable**: Enable `set -u` and check variable initialization order
