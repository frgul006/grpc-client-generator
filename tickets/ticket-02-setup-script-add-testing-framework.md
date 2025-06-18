# Ticket 02: Add Testing Framework

## Epic/Scope
setup-script

## What
Implement a testing framework for setup.sh using bats-core (Bash Automated Testing System) to add automated testing for critical setup and validation functions.

## Why
- **Regression Protection**: Prevent breaking changes to setup functionality
- **Confidence**: Enable safe refactoring and feature additions
- **Documentation**: Tests serve as executable documentation of expected behavior
- **CI/CD Integration**: Automated testing in continuous integration pipeline
- **Reliability**: Catch edge cases and platform-specific issues early

As setup.sh becomes more sophisticated (600+ lines), manual testing becomes insufficient and error-prone. Automated tests are essential for maintaining reliability.

## How

### 1. Install bats-core
- Add bats-core installation to setup.sh tool installation section
- Support installation via package managers (brew, apt) and git submodules
- Add version verification and availability checks

### 2. Test Structure Setup
- Create `tests/` directory in project root
- Create `tests/setup.bats` for main test suite
- Add `tests/helper.bash` for shared test utilities
- Create `tests/fixtures/` for test data and mock responses

### 3. Test Categories

#### Environment Validation Tests
- Test Node.js version checking (valid/invalid versions)
- Test port conflict detection (with mock lsof output)
- Test Docker availability and network creation
- Test git repository detection

#### Tool Installation Tests
- Test tool availability checking
- Test version reporting functionality
- Mock external commands for reliable testing

#### CLI Interface Tests
- Test all command-line flags (--help, --status, --version, --cleanup)
- Test error handling for invalid arguments
- Test output formatting and logging

#### Integration Tests
- Test complete setup workflow in clean environment
- Test cleanup functionality
- Test status reporting accuracy

### 4. Test Infrastructure
- Create test doubles/mocks for external commands
- Add test environment isolation
- Implement setup/teardown functions for test state

### 5. CI Integration
- Add `make test` command to run all tests
- Include in GitHub Actions workflow (if exists)
- Add test coverage reporting

## Definition of Done

- [ ] bats-core is installable via setup.sh on both macOS and Linux
- [ ] `tests/` directory exists with organized test structure
- [ ] `tests/setup.bats` contains comprehensive test suite covering:
  - [ ] Environment validation functions
  - [ ] CLI argument parsing
  - [ ] Tool installation checks
  - [ ] Status reporting functionality
- [ ] `tests/helper.bash` provides reusable test utilities
- [ ] `make test` command runs all tests successfully
- [ ] Tests are isolated and don't affect host system
- [ ] All tests pass on clean macOS and Linux environments
- [ ] Test documentation explains how to run and extend tests
- [ ] setup.sh --status includes bats availability check

## Priority
High

## Estimated Effort
Large (4-6 hours)

## Dependencies
- None (can be done independently)

## Risks
- Test environment isolation complexity
- Mocking external dependencies (docker, npm, etc.)
- Platform-specific test differences
- Test maintenance overhead as script evolves