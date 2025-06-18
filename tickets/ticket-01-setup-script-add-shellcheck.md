# Ticket 01: Add ShellCheck Integration

## Epic/Scope
setup-script

## What
Integrate ShellCheck static analysis tool into the development workflow for setup.sh to catch potential bugs, improve code quality, and enforce shell scripting best practices.

## Why
- **Code Quality**: ShellCheck identifies common shell scripting pitfalls and anti-patterns
- **Bug Prevention**: Catches subtle bugs that could cause setup failures in production
- **Maintainability**: Enforces consistent coding standards across the script
- **Documentation**: ShellCheck warnings often reveal unclear or problematic code patterns
- **CI Integration**: Automated checking prevents regressions and ensures quality

The current setup.sh is 600+ lines of sophisticated bash code. As it grows in complexity, static analysis becomes crucial for maintaining reliability.

## How

### 1. Install ShellCheck
- Add ShellCheck installation to setup.sh tool installation section
- Support both macOS (brew) and Linux installation methods
- Add version check and installation verification

### 2. Create ShellCheck Configuration
- Create `.shellcheckrc` file in project root with appropriate rules
- Configure exclude patterns for intentional violations (if any)
- Set severity levels and output format

### 3. Integration Points
- **Local Development**: Add `make lint-shell` command to Makefile
- **Pre-commit**: Consider adding to pre-commit hooks
- **Documentation**: Update README with shellcheck usage instructions

### 4. Fix Existing Issues
- Run ShellCheck on current setup.sh
- Address all high and medium severity findings
- Document any intentionally ignored warnings

### 5. Enforcement
- Add shellcheck command to setup.sh --status output
- Include in "verify environment" checks

## Definition of Done

- [ ] ShellCheck is installable via setup.sh on both macOS and Linux
- [ ] `.shellcheckrc` configuration file exists with project-appropriate rules
- [ ] All existing ShellCheck warnings in setup.sh are resolved or documented
- [ ] `make lint-shell` command runs ShellCheck and returns clean results
- [ ] setup.sh --status includes ShellCheck availability check
- [ ] Documentation updated with ShellCheck usage instructions
- [ ] ShellCheck version requirement documented (minimum SC0.7.0+)

## Priority
High

## Estimated Effort
Medium (2-3 hours)

## Dependencies
- None

## Risks
- Potential large number of existing violations requiring cleanup
- Team adoption of new linting workflow
- Integration complexity with existing tools