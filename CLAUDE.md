# CLAUDE.md

## Core Behavior

Be brutally honest, don't be a yes man. If I am wrong, point it out bluntly. I need honest feedback on my code. Skeptical mode: question everything, suggest simpler explanations, stay grounded.

## Development Workflow: Explore-Plan-Code-Commit

### 1. Explore
Understand the codebase first. Use available tools to review relevant files and form a clear picture of the current state before proposing changes.

### 2. Plan
Present a detailed, step-by-step implementation plan. List files to create or modify. **Wait for user approval before proceeding.**

### 3. Code
Execute the approved plan methodically. Apply changes systematically.

### 4. Commit
After verification, create commit with descriptive message and pull request.

## Git Workflow

- **MANDATORY**: Create new branch before starting any coding task
- Branch naming: kebab-case with task description (e.g., `feat/user-auth`, `fix/memory-leak`)
- **MANDATORY**: Run `lab preflight` before `mcp__zen__precommit`
- **MANDATORY**: Use `mcp__zen__precommit` before all commits
- **MANDATORY**: Create pull request after completion - never push directly to main

## Bash Commands

- `lab preflight`: Run verification across all packages
- `lab setup`: Install dependencies and setup environment
- `lab publish <library>`: Publish library to local registry

## Essential Rules

- Create TodoWrite items for documentation updates
- Progress documentation is MANDATORY
- Use zen tools for complex technical challenges
- Reference `@docs/` files for detailed guidelines:
  - `@docs/coding-standards.md` - Code style and quality requirements
  - `@docs/workflows.md` - Ticketing system and development processes
  - `@docs/tool-reference.md` - Zen and Context7 tool descriptions

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
