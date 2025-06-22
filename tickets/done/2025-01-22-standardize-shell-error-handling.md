# Standardize shell script error handling to strict mode

## Problem

Shell scripts use inconsistent error handling:
- CLI scripts use `set -Eeuo pipefail` (strict error handling)
- E2E test scripts use only `set -e` (basic error handling)

This inconsistency violates CLAUDE.md guidelines which specify using strict error handling in all scripts.

## Solution

Update all shell scripts to use `set -Eeuo pipefail` for consistent, strict error handling as specified in CLAUDE.md.

## Location

- `apis/product-api/scripts/test-e2e.sh` - Uses only `set -e`
- `apis/user-api/scripts/test-e2e.sh` - Uses only `set -e`
- Any other shell scripts using basic error handling