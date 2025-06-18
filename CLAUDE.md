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
