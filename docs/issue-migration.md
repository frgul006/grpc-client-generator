# Issue Migration Reference

This document maps the original local ticket/requirement files to their corresponding GitHub issues.

**Migration Date**: 2025-06-30
**Total Items Migrated**: 31

## Ticket Mapping

| Original File                                      | GitHub Issue | Title                                  | Status   |
| -------------------------------------------------- | ------------ | -------------------------------------- | -------- |
| 2025-01-19-implement-lab-dev-command.md            | #15          | Implement lab dev command              | Done     |
| 2025-01-22-add-missing-return-types.md             | #22          | Add missing return types               | Done     |
| 2025-01-22-create-grpc-mock-types.md               | #29          | Create gRPC mock types                 | Done     |
| 2025-01-22-remove-dead-code-shell-functions.md     | #33          | Remove dead code shell functions       | Done     |
| 2025-01-22-remove-unused-dependencies.md           | #10          | Remove unused dependencies             | Done     |
| 2025-01-22-split-large-cli-modules.md              | #19          | Split large CLI modules                | Done     |
| 2025-01-22-standardize-repository-signatures.md    | #27          | Standardize repository signatures      | Done     |
| 2025-01-22-standardize-shell-error-handling.md     | #14          | Standardize shell error handling       | Done     |
| ticket-02-cli-refactor-modularize-lab-script.md    | #39          | CLI refactor: modularize lab script    | Done     |
| ticket-03-add-preflight-command.md                 | #42          | Add preflight command                  | Done     |
| ticket-04-enhance-preflight-ui-feedback.md         | #43          | Enhance preflight UI feedback          | Done     |
| 2025-01-22-consolidate-eslint-configs.md           | #11          | Consolidate ESLint configs             | Rejected |
| 2025-01-22-consolidate-tsconfig.md                 | #18          | Consolidate tsconfig                   | Rejected |
| 2025-01-22-consolidate-vitest-configs.md           | #28          | Consolidate Vitest configs             | Rejected |
| 2025-01-22-create-base-repository-class.md         | #34          | Create base repository class           | Rejected |
| 2025-01-22-create-grpc-server-factory.md           | #36, #13     | Create gRPC server factory             | Rejected |
| 2025-01-22-extract-error-handling-utilities.md     | #20          | Extract error handling utilities       | Rejected |
| 2025-01-22-extract-shared-test-setup.md            | #26          | Extract shared test setup              | Rejected |
| 2025-01-22-extract-shell-logging-utilities.md      | #31          | Extract shell logging utilities        | Rejected |
| 2025-01-22-fix-forbidden-any-violations.md         | #37          | Fix forbidden any violations           | Rejected |
| ticket-01-setup-script-add-shellcheck.md           | #12          | Setup script: add shellcheck           | Active   |
| ticket-05-fix-cli-global-dependencies.md           | #16          | Fix CLI global dependencies            | Active   |
| ticket-06-refactor-dev-command.md                  | #21          | Refactor dev command                   | Active   |
| ticket-07-refactor-preflight-command.md            | #24          | Refactor preflight command             | Active   |
| ticket-08-setup-script-install-all-dependencies.md | #32          | Setup script: install all dependencies | Active   |

## RFC Mapping

| Original Directory                                    | GitHub Issue | RFC Title                              | Status |
| ----------------------------------------------------- | ------------ | -------------------------------------- | ------ |
| 2025-06-29-1954-preflight-ui-feedback                 | #35, #38     | Preflight UI feedback                  | Active |
| 2025-06-29-2306-core-generator                        | #23, #40     | Core generator                         | Active |
| 2025-06-29-2347-revisit-core-generator                | #30, #41     | Revisit core generator                 | Active |
| 2025-06-30-0755-setup-script-install-all-dependencies | #17          | Setup script: install all dependencies | Active |
| 2025-06-30-0756-setup-script-install-dependencies     | #25          | Setup script: install dependencies     | Active |

## Quick Search Tips

- Use label filters: `label:epic/cli label:status/done`
- Search by original ticket: `"ticket-01" in:body`
- Find all RFCs: `label:type/rfc`
- Active work: `label:status/todo label:status/in-progress`

## Label Guide

### Epic Labels

- `epic/cli` - CLI improvements
- `epic/protoc-plugin` - protoc plugin features
- `epic/golang-client` - Go client generation
- `epic/java-client` - Java client generation
- `epic/python-client` - Python client generation
- `epic/docs` - Documentation efforts

### Type Labels

- `type/feature` - New feature
- `type/bug` - Bug fix
- `type/enhancement` - Improvement to existing feature
- `type/docs` - Documentation
- `type/test` - Testing improvements
- `type/rfc` - RFC requirement

### Status Labels

- `status/todo` - Not started
- `status/in-progress` - Work in progress
- `status/review` - In review
- `status/done` - Completed
- `status/blocked` - Blocked

### Priority Labels

- `priority/critical` - Critical issue
- `priority/high` - High priority
- `priority/medium` - Medium priority
- `priority/low` - Low priority
