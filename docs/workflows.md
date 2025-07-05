# Development Workflows

## Issue Management System

When you identify improvements that would be scope creep for the current task, create a GitHub issue.

### When to Create an Issue

Create an issue ONLY if the improvement:

- Is outside current task scope (would be scope creep)
- Is non-trivial (more than a simple fix, affects multiple lines/files)
- Adds clear value (maintainability, performance, security, or developer experience)

### How to Create a GitHub Issue

1. **Check for duplicates**: Search existing issues with `gh issue list --search "keywords"`
2. **Create via CLI**: Use `gh issue create` and select the appropriate template
3. **Apply labels**: Use appropriate epic, type, priority, and status labels
4. **Link to PR**: Reference the issue number in commits and pull requests

### Issue Templates

The repository includes structured templates for:

- **Development Tickets**: For features, bugs, and improvements
- **RFCs**: For architectural decisions and major changes

### Working with Issues

1. **Claim an issue**: Comment on the issue or assign yourself
2. **Create branch**: Include issue number (e.g., `feat/user-auth-123`)
3. **Reference in commits**: Use `#123` in commit messages
4. **Link PR**: GitHub automatically links PRs that reference issues

### Important Notes

- Use the GitHub web interface or CLI for all issue operations
- Follow the label conventions defined in CLAUDE.md
- Issues are automatically closed when linked PRs are merged
