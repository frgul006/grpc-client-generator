# Ticketing System

## Overview

This directory contains structured tickets for tracking tasks, improvements, and features across the gRPC experiment project. Each ticket follows a standardized format to ensure clarity and actionable outcomes.

## Ticket Naming Convention

Tickets use the following format:
```
ticket-{number}-{epic}-{description}.md
```

**Examples:**
- `ticket-01-setup-script-add-shellcheck.md`
- `ticket-02-product-api-improve-error-handling.md`
- `ticket-03-docs-update-readme.md`

## Epic Categories

| Epic | Purpose | Examples |
|------|---------|----------|
| **setup-script** | Improvements to setup.sh | Testing, linting, error handling |
| **product-api** | API-related tasks | New endpoints, refactoring, optimization |
| **registry** | Verdaccio registry tasks | Configuration, deployment, monitoring |
| **docs** | Documentation tasks | README updates, API docs, guides |
| **ci-cd** | Build/deployment tasks | GitHub Actions, testing, releases |
| **tooling** | Development tooling | IDE configs, linters, formatters |

## Ticket Template

Each ticket must contain the following sections:

### Epic/Scope
The category this ticket belongs to (e.g., setup-script)

### What
Clear, concise description of what needs to be done.

### Why
Business or technical justification for this work. Why is this important?

### How
Step-by-step approach to implement the solution. Include:
- Technical approach
- Key implementation steps
- Dependencies or prerequisites
- Risks or considerations

### Definition of Done
Specific, measurable criteria that must be met for the ticket to be considered complete.

### Priority
- **High**: Critical for project success, blocks other work
- **Medium**: Important but not blocking
- **Low**: Nice to have, can be deferred

### Estimated Effort
- **Small**: < 1 hour
- **Medium**: 1-4 hours  
- **Large**: > 4 hours

## Usage Guidelines

1. **Create tickets** for any non-trivial work before starting
2. **Reference tickets** in commit messages and pull requests
3. **Update tickets** as work progresses or requirements change
4. **Close tickets** when Definition of Done is met
5. **Use epic prefixes** to group related work

## Example Workflow

1. Identify need for improvement
2. Create ticket with proper naming convention
3. Fill out all template sections
4. Reference ticket number in commits: `git commit -m "feat: add shellcheck integration (ticket-01)"`
5. Mark ticket as complete when DoD is satisfied

## Benefits

- **Traceability**: Link code changes to business requirements
- **Documentation**: Preserve context and reasoning for future reference
- **Planning**: Better estimation and resource allocation
- **Collaboration**: Clear communication about work scope and status