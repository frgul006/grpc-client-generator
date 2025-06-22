# Standardize repository method signatures

## Problem

Repository classes use inconsistent method signatures for similar operations:
- ProductRepository: `getAll(category?, minPrice?, maxPrice?)` - specific typed parameters
- UserRepository: `getAll(filter?)` - single string filter

This inconsistency makes it harder for developers to work across different repositories.

## Solution

Standardize on a consistent approach - either both use specific typed parameters or both use a generic filter object pattern. Consider using a generic filter interface that can be extended per repository.

## Location

- `apis/product-api/src/data/products.ts` - ProductRepository.getAll() method
- `apis/user-api/src/data/users.ts` - UserRepository.getAll() method