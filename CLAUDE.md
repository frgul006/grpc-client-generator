# CLAUDE.md

## Core Behavior

Be brutally honest, don't be a yes man. If I am wrong, point it out bluntly. I need honest feedback on my code. Skeptical mode: question everything, suggest simpler explanations, stay grounded.

## Issue Management Workflow

1. **Check Existing Issues**
   - Search GitHub Issues for related work
   - Check migration map in `/docs/issue-migration.md` for historical context

2. **Create New Issues**
   - Use appropriate issue template
   - Apply relevant labels (epic, type, status, priority)
   - Link to related issues or PRs

3. **Work on Issues**
   - Assign yourself to the issue
   - Update status label to `status/in-progress`
   - Reference issue in commit messages: `feat: implement X (#123)`
   - Link PR to issue for automatic closure

## Label Convention

- **Epic Labels**: `epic/cli`, `epic/protoc-plugin`, `epic/*-client`
- **Type Labels**: `type/feature`, `type/bug`, `type/enhancement`, `type/docs`, `type/rfc`
- **Status Labels**: `status/todo`, `status/in-progress`, `status/review`, `status/done`, `status/blocked`
- **Priority Labels**: `priority/critical`, `priority/high`, `priority/medium`, `priority/low`

## Development Workflow: Explore-Plan-Code-Commit-Track

### 1. Explore
- Check GitHub Issues for related work
- Review `/docs/issue-migration.md` for historical context
- Understand the codebase first

### 2. Plan
- Create or update GitHub Issue with implementation plan
- Present detailed steps
- **Wait for user approval before proceeding**

### 3. Code
- Reference issue number in branch name: `feat/user-auth-123`
- Execute the approved plan methodically

### 4. Commit
- Include issue reference: `fixes #123` or `relates to #123`
- Create PR linked to issue

### 5. Track
- Update issue status labels
- Close issue when PR is merged

## Git Workflow

- **MANDATORY**: Create new branch before starting any coding task
- Branch naming: kebab-case with task description and issue reference (e.g., `feat/user-auth-123`, `fix/memory-leak-456`)
- **MANDATORY**: Run `lab preflight` before `mcp__zen__precommit`
- **MANDATORY**: Use `mcp__zen__precommit` before all commits
- **MANDATORY**: Create pull request after completion - never push directly to main

## Bash Commands

- `lab preflight`: Run verification across all packages
- `lab setup`: Install dependencies and setup environment
- `lab publish <library>`: Publish library to local registry

## Essential Rules

- Use GitHub Issues for all task tracking
- Progress documentation is MANDATORY
- Use zen tools for complex technical challenges
- Reference `@docs/` files for detailed guidelines:
  - `@docs/coding-standards.md` - Code style and quality requirements
  - `@docs/workflows.md` - Development processes
  - `@docs/tool-reference.md` - Zen and Context7 tool descriptions

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
