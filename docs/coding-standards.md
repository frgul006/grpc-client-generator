# Coding Standards

## Code Style

- Use ES modules (import/export) syntax
- Destructure imports when possible: `import { Logger } from './logger'`
- TypeScript strict mode enabled - all types must be explicit
- Use type aliases over interfaces for object shapes
- Prefer `const` over `let`, never use `var`
- Test names: use descriptive phrases, avoid "should"
- **FORBIDDEN**: Using `any` is strictly forbidden

## Shell Scripting Guidelines

- Use `set -Eeuo pipefail` for strict error handling in all scripts
- Use `sleep` instead of `timeout` command (timeout doesn't work as expected on macOS)
- Source modules in dependency order (utilities first, then dependent modules)
- Initialize variables after all modules are loaded
- Use `"$variable"` quoting for all variable expansions
- Use `mktemp -d` for temporary directories, always clean up with `rm -rf`
- For modular scripts, use initialization functions rather than inline variable assignment

## Quality Requirements

- Always test package.json scripts after adding them
- Don't use "should" in test names
- Test functions must use identical commands to the real workflows they validate
- Test function parameters (flags, options, paths) must exactly match production usage
- Before committing, manually verify test commands work by running them in the actual environment