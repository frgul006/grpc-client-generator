# Fix CLAUDE.md violations - eliminate forbidden any usage

## Problem

The codebase has 56+ instances of `any` type usage in test files, directly violating the CLAUDE.md rule that states "Using `any` is strictly forbidden". This reduces type safety and can hide runtime errors during refactoring.

## Solution

Create proper mock types for gRPC testing and replace all `as any` assertions with properly typed mocks. Define MockServerUnaryCall<T> and MockSendUnaryData<T> interfaces that match the gRPC call structure.

## Location

- `apis/product-api/src/__tests__/unit/product-service.test.ts` - 32+ instances of `mockCall as any`
- `apis/user-api/src/__tests__/unit/user-service.test.ts` - 24+ instances of `mockCall as any`
- `apis/user-api/src/__tests__/unit/user-repository.test.ts:267` - Explicit `any` casting with ESLint disable