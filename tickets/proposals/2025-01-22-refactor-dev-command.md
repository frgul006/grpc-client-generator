# Refactor complex dev command orchestration

## Problem

The `handle_dev_command()` function in commands.sh is 106 lines long with complex orchestration logic, nested loops, and signal handling all in one function. This makes it difficult to understand and maintain.

## Solution

Split the function into smaller, focused functions:
- Extract package discovery logic
- Separate watcher setup from main orchestration
- Extract signal handling setup
- Create clear separation between setup and execution phases

## Location

- `cli/lib/commands.sh` - handle_dev_command() function (106 lines)