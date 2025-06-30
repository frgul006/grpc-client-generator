# Create base repository class for common CRUD operations

## Problem

ProductRepository and UserRepository share 85% similar code for CRUD operations but implement them separately. Common patterns like getAll, create, update, delete are duplicated with minor variations.

## Solution

Create a generic base repository class that implements common CRUD operations with proper TypeScript generics, allowing product and user repositories to extend and customize only what's unique.

## Location

- `apis/product-api/src/data/products.ts` - ProductRepository with CRUD operations
- `apis/user-api/src/data/users.ts` - UserRepository with similar CRUD operations
- Create: `libs/data-utils/base-repository.ts`