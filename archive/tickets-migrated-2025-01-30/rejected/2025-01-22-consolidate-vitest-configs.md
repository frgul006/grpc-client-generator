# Consolidate duplicated Vitest configurations

## Problem

Vitest configuration files are 100% identical across product-api and user-api (35 lines of exact duplication), making it harder to maintain consistent test settings.

## Solution

Create a shared Vitest base configuration that both APIs can extend, ensuring consistent test coverage thresholds and settings.

## Location

- `apis/product-api/vitest.config.ts` - 35 lines duplicated
- `apis/user-api/vitest.config.ts` - 35 lines duplicated
- Create: `shared-configs/vitest.config.base.ts`