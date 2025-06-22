# Create proper TypeScript types for gRPC mocking

## Problem

Test files extensively use `as any` type assertions for mocking gRPC calls, violating type safety. This makes tests brittle and removes IDE support for test authoring.

## Solution

Create a shared test utilities library with proper mock types:
- `MockServerUnaryCall<T>` interface for request mocking
- `MockSendUnaryData<T>` type for callback mocking
- Helper functions to create type-safe mocks

## Location

- Create new file: `libs/test-utils/grpc-mocks.ts`
- Update all test files to import and use these types instead of `any` assertions