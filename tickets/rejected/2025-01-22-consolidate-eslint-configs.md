# Consolidate duplicated ESLint configurations

## Problem

ESLint configuration files are 100% identical across product-api and user-api (46 lines of exact duplication), making it harder to maintain consistent linting rules.

## Solution

Create a shared ESLint configuration that both APIs can extend, reducing duplication and ensuring consistency.

## Location

- `apis/product-api/eslint.config.js` - 46 lines duplicated
- `apis/user-api/eslint.config.js` - 46 lines duplicated
- Create: `shared-configs/eslint.config.js` or root-level shared config