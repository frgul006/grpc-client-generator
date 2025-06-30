# Initial Request: Setup Script Install All Dependencies

## Original Request
Enhance the `lab setup` command to install dependencies across all package.json files in the monorepo, not just the product-api package.

## Context from Ticket
Currently, the setup only installs dependencies for `apis/product-api`, leaving other packages without their required dependencies. The repository contains multiple packages (APIs, libraries, services) that each have their own dependencies.

## Problem Statement
The current implementation in `cli/lib/setup/infrastructure.sh:68-99` only handles the product-api directory, leaving developers to manually install dependencies for other packages.

## Expected Outcome
- `lab setup` command should discover and install dependencies for all package.json files in the monorepo
- Installation should respect dependency order (libraries first, then APIs/services)
- Existing functionality should remain unchanged
- Progress reporting should show which package is being processed