# Modularize large test files by feature

## Problem

Test files have grown very large, making it difficult to find specific tests:
- product-service.test.ts: 690 lines
- product-repository.test.ts: 626 lines

This makes test maintenance harder and increases cognitive load.

## Solution

Split test files by feature/method:
- product-service.test.ts: Split into getProduct.test.ts, createProduct.test.ts, etc.
- product-repository.test.ts: Group by CRUD operations and edge cases

## Location

- `apis/product-api/src/__tests__/unit/product-service.test.ts` - 690 lines
- `apis/product-api/src/__tests__/unit/product-repository.test.ts` - 626 lines