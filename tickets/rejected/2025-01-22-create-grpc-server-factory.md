# Create generic gRPC server factory to eliminate duplication

## Problem

The main server entry points (index.ts) in product-api and user-api are 90% similar, differing only in port numbers, service names, and import paths. This violates DRY principle and makes it harder to implement server-wide features.

## Solution

Create a generic gRPC server factory that accepts configuration (port, service name, implementation) and handles all common setup, logging, and shutdown logic.

## Location

- `apis/product-api/src/index.ts` - 90% similar to user-api
- `apis/user-api/src/index.ts` - 90% similar to product-api
- Create: `libs/grpc-utils/server-factory.ts`