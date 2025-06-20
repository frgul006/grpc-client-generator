# Enhance Preflight UI with Better Progress Feedback

## Problem

While the dialog-based scrolling UI shows real-time output, there are opportunities to improve the developer experience further by adding progress indicators, filtering verbose output, and providing better visual feedback.

## Solution

1. Add progress bar showing X/Y packages completed
2. Filter output to show only key events (test names, errors) instead of full verbose output
3. Add color coding to the live log (green for pass, red for fail)
4. Consider alternative UI for systems without dialog (e.g., simple progress dots)
5. Add estimated time remaining based on historical run times

## Location

- `cli/lib/preflight.sh:L30-L59` (update _run_single_verify for output filtering)
- `cli/lib/preflight.sh:L140-L194` (enhance UI launch and progress tracking)