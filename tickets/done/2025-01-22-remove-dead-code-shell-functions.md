# Remove unused shell functions from CLI

## Problem

The `show_progress()` function in common.sh is defined but never called anywhere in the codebase, adding unnecessary maintenance burden.

## Solution

Delete the unused `show_progress()` function from common.sh.

## Location

- `cli/lib/common.sh` - Remove the show_progress() function definition