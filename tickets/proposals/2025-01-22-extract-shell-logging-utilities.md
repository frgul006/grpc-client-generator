# Extract duplicated shell logging utilities

## Problem

E2E test scripts duplicate CLI logging functions (log_info, log_error, etc.) but with simpler implementations, violating DRY principle and creating maintenance burden.

## Solution

Extract shared bash utilities for logging, error handling, and common operations that can be sourced by both CLI scripts and test scripts.

## Location

- `cli/lib/common.sh` - Original logging functions
- `apis/product-api/scripts/test-e2e.sh` - Duplicated simplified logging
- `apis/user-api/scripts/test-e2e.sh` - Duplicated simplified logging
- Create: `scripts/common/logging.sh` or similar shared location