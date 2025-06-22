# Extract gRPC error handling utilities

## Problem

Product-api uses helper functions for validation and error handling (`validateId`, `handleNotFound`) while user-api repeats the same error handling code inline multiple times, violating DRY principle.

## Solution

Extract common gRPC error handling patterns into shared utilities that both services can use for consistent error responses.

## Location

- `apis/product-api/src/service/product-service.ts` - Has validateId() and handleNotFound() helpers
- `apis/user-api/src/service/user-service.ts` - Repeats error handling inline
- Create: `libs/grpc-utils/error-handlers.ts`