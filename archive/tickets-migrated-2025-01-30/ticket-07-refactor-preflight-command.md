# Refactor complex preflight command function

## Problem

The `handle_preflight_command()` function in preflight.sh is 174 lines long with 4+ levels of nesting, handling complex parallel execution, staging logic, and cleanup. This violates single responsibility principle and makes the code hard to maintain.

## Solution

Split the function into smaller, focused functions:
- Extract staging logic into `stage_preflight_checks()`
- Extract result aggregation into `aggregate_check_results()`
- Extract cleanup handling into `cleanup_preflight()`
- Keep main function as orchestrator only

## Location

- `cli/lib/preflight.sh` - handle_preflight_command() function (174 lines)