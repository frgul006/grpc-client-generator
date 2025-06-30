# Remove unused dependencies from all packages

## Problem

The `@vitest/ui` dependency is present in all package.json files but never used in any scripts, adding 5-10MB per package (25-30MB total) to the project size unnecessarily.

## Solution

Remove `@vitest/ui` from all package.json files and run npm install to update lock files.

## Location

- `apis/product-api/package.json`
- `apis/user-api/package.json`
- `libs/grpc-client-generator/package.json`
- `services/example-service/package.json`
- Root `package.json` (if present)