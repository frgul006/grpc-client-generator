# CLAUDE.md

## Code style

- Use ES modules (import/export) syntax
- Destructure imports when possible: `import { Logger } from './logger'`
- TypeScript strict mode enabled - all types must be explicit
- Use type aliases over interfaces for object shapes
- Prefer `const` over `let`, never use `var`
- Test names: use descriptive phrases, avoid "should"

## Rules

- Always test package.json scripts after adding them
- Don't use "should" in test names
- **CRITICAL**: Create TodoWrite items for documentation updates to ensure they're not forgotten
- **MANDATORY**: NEVER create git commits without using mcp**zen**precommit first
- Progress documentation is MANDATORY - the user will verify this was done
- Use zen and context7 tools for complex technical challenges

## Enhanced AI Capabilities: Zen and Context7

## Zen Tools (mcp__zen__*)

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

### Context7 Tools (mcp__context7__*)

**Up-to-date documentation and library research:**

- **`mcp__context7__resolve-library-id`** - Find Context7-compatible library IDs
- **`mcp__context7__get-library-docs`** - Fetch current documentation for libraries

**When to use Context7:**

- Need current documentation for libraries/frameworks
- Looking for best practices and examples
- Researching how to use specific tools
- When web search isn't sufficient for technical details

---

# Ticketing System

## Overview

This project uses a structured ticketing system located in `/tickets` to track tasks, improvements, and features. This system helps maintain clear documentation, traceability, and planning across the codebase.

## When to Use Tickets

**ALWAYS create tickets for:**
- Non-trivial improvements or features (>1 hour of work)
- Complex bug fixes requiring investigation
- Documentation updates that span multiple files
- Infrastructure or tooling changes
- Refactoring efforts

**DON'T create tickets for:**
- Simple typo fixes
- Minor documentation updates
- Emergency hotfixes
- Trivial code cleanup

## Ticket Structure

### Naming Convention
```
ticket-{number}-{epic}-{description}.md
```

**Examples:**
- `ticket-01-setup-script-add-shellcheck.md`
- `ticket-02-product-api-improve-error-handling.md`
- `ticket-03-docs-update-readme.md`

### Epic Categories
- **setup-script**: Improvements to setup.sh
- **product-api**: API-related tasks  
- **registry**: Verdaccio registry tasks
- **docs**: Documentation tasks
- **ci-cd**: Build/deployment tasks
- **tooling**: Development tooling

### Required Template Sections
- **Epic/Scope**: Category (e.g., setup-script)
- **What**: Clear description of the task
- **Why**: Business/technical justification
- **How**: Implementation approach and steps
- **Definition of Done**: Specific, measurable completion criteria
- **Priority**: High/Medium/Low
- **Estimated Effort**: Small/Medium/Large

## Workflow

1. **Create tickets** for planned work before starting
2. **Reference tickets** in commit messages: `feat: add shellcheck integration (ticket-01)`
3. **Update tickets** as work progresses or requirements change
4. **Close tickets** when Definition of Done is met
5. **Use epic prefixes** to group and organize related work

## Benefits

- **Traceability**: Link code changes to business requirements
- **Documentation**: Preserve context and reasoning
- **Planning**: Better estimation and resource allocation
- **Collaboration**: Clear communication about scope and status

For detailed guidelines, see `/tickets/README.md`.