# Fix CLI modules global variable dependencies

## Problem

All CLI modules depend on global variables (REPO_ROOT, VERBOSE_MODE, etc.) creating tight coupling and making it difficult to test or reuse individual modules.

## Solution

Refactor to use dependency injection or a configuration object pattern. Pass required variables as parameters or create a context object that modules can accept.

## Location

- All files in `cli/lib/` - Depend on global variables
- Particularly: REPO_ROOT, VERBOSE_MODE, STATE_FILE globals