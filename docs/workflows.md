# Development Workflows

## Ticketing System

When you identify improvements that would be scope creep for the current task, create a proposal ticket.

### When to Create a Ticket

Create a ticket ONLY if the improvement:

- Is outside current task scope (would be scope creep)
- Is non-trivial (more than a simple fix, affects multiple lines/files)
- Adds clear value (maintainability, performance, security, or developer experience)

### How to Create a Proposal Ticket

1. **Check for duplicates**: Quick scan of `/tickets/proposals/` filenames
2. **File naming**: `YYYY-MM-DD-brief-description.md` (e.g., `2024-10-27-refactor-auth-logic.md`) - use kebab-case for description
3. **Location**: Create in `/tickets/proposals/` (create directory if missing)
4. **Content format**:

   ```markdown
   # Brief descriptive title

   ## Problem

   Briefly describe the issue or opportunity (1-2 sentences).

   ## Solution

   Brief description of the proposed change.

   ## Location

   - `path/to/file.js:L10-L25` (relative to repository root)
   - `path/to/another.py:L102` (relative to repository root)
   ```

### Important Notes

- Keep proposals concise - detailed planning happens if/when humans activate the ticket
- You only create proposals; humans handle grooming, prioritization, and moving to done
- Never edit existing tickets or move tickets between directories