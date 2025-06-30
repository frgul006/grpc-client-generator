# Extract duplicated test setup utilities

## Problem

The test setup files in product-api and user-api are 100% identical (48 lines of exact duplication), violating DRY principle and making maintenance harder.

## Solution

Extract the shared test setup code into a common test utilities library that both APIs can import.

## Location

- `apis/product-api/src/__tests__/setup.ts` - 48 lines duplicated
- `apis/user-api/src/__tests__/setup.ts` - 48 lines duplicated
- Create: `libs/test-utils/grpc-test-setup.ts` - Shared implementation