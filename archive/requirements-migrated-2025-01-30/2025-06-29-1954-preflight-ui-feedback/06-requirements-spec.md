# Requirements Specification - Enhance Preflight UI with Better Progress Feedback

## Problem Statement

The current `lab preflight` command produces overwhelming verbose output that creates cognitive overload. Users see interleaved output from multiple packages running in parallel, with no clear indication of progress or which packages are in what state. This makes it difficult to understand if the verification is progressing normally or stuck.

## Solution Overview

Transform the preflight command from a "verbose process monitor" into a "confident status dashboard" that shows packages as atomic units progressing through verification phases. The new UI will provide clear visual feedback with in-place updates, showing each package's current phase and timing information.

## Functional Requirements

### 1. Status Dashboard Display

- Show a fixed-position dashboard with packages listed as rows
- Each package displays its current phase with visual indicators:
  - ⏳ Pending (gray/dim)
  - 🟡 In Progress (yellow)
  - ✅ Success (green)
  - ❌ Failed (red)
- Display phase progression: lint → format → build → test
- Show timing for each phase (e.g., "lint: 1.2s")
- Maintain stage-based organization (Stage 1: Producers, Stage 2: Consumers)

### 2. Progress Parsing

- Parse npm script output to detect phase transitions
- Recognize common patterns in npm output:
  - ESLint completion messages
  - Prettier format check results
  - TypeScript compilation progress
  - Test runner output
- Update package status in real-time as phases complete

### 3. TTY Detection and Fallback

- Automatically detect if output is to a TTY using `[[ -t 1 ]]`
- When not a TTY (CI/CD, piped output):
  - Fall back to traditional verbose output
  - Maintain current behavior for compatibility
- Respect `NO_COLOR` or `TERM=dumb` environment variables

### 4. Verbose Mode Flag

- Add `--verbose` or `-v` flag to force traditional output
- Flag overrides TTY detection
- Useful for debugging when dashboard hides important details

### 5. Error Handling

- On package failure:
  - Mark package as failed with ❌
  - Display failed package's log output immediately below summary
  - Continue running other packages (unless dependency failed)
- Preserve all log files in temp directory as currently done

### 6. Fixed-Position Updates

- Use ANSI escape sequences for cursor positioning
- Clear and redraw dashboard lines to show updates
- Handle terminal resize gracefully
- Show last N packages that fit in terminal height

## Technical Requirements

### 1. File Modifications

#### cli/lib/preflight.sh

- **Lines 48-95**: Modify `_run_single_verify` to:
  - Parse output for phase detection
  - Write phase updates to status files
  - Maintain package log files
- **Lines 140-194**: Replace tail viewer with:
  - Dashboard renderer function
  - Status update loop
  - TTY detection logic
- **New functions to add**:
  - `_render_dashboard()` - Main dashboard display
  - `_parse_npm_phase()` - Detect current phase from output
  - `_update_package_status()` - Update status files
  - `_format_phase_status()` - Format phase with timing

### 2. State Management

- Create status files in temp directory:
  - `${temp_dir}/status/${package_name}.phase` - Current phase
  - `${temp_dir}/status/${package_name}.start` - Phase start time
  - `${temp_dir}/status/${package_name}.phases` - Completed phases with timings
- Use file-based state for parallel process communication

### 3. ANSI Escape Sequences

- Cursor positioning: `\033[${row};${col}H`
- Clear line: `\033[K`
- Save/restore cursor: `\033[s` and `\033[u`
- Colors: Use existing definitions from common.sh

### 4. Command Line Parsing

- Add support for `--verbose` or `-v` flag
- Parse before main preflight logic
- Set `VERBOSE_OUTPUT=true` when flag present

## Implementation Hints

### Phase Detection Patterns

```bash
# Lint phase
if [[ "$line" =~ "eslint" ]] || [[ "$line" =~ "ESLint" ]]; then
    phase="lint"
fi

# Format phase
if [[ "$line" =~ "prettier" ]] || [[ "$line" =~ "Checking formatting" ]]; then
    phase="format"
fi

# Build phase
if [[ "$line" =~ "tsc" ]] || [[ "$line" =~ "tsup" ]] || [[ "$line" =~ "Building" ]]; then
    phase="build"
fi

# Test phase
if [[ "$line" =~ "vitest" ]] || [[ "$line" =~ "PASS" ]] || [[ "$line" =~ "FAIL" ]]; then
    phase="test"
fi
```

### Dashboard Layout Example

```
🚀 Preflight Verification (4 packages)

Stage 1: Core Libraries
✅ grpc-client-generator    lint:1.2s format:0.8s build:2.1s test:3.4s (7.5s)

Stage 2: Services (parallel)
🟡 user-api                 lint:0.9s format:0.5s →build
🟡 product-api              lint:1.1s →format
⏳ example-service          (pending)
```

## Acceptance Criteria

1. **Visual Clarity**: Dashboard shows clear package states without scrolling
2. **Real-time Updates**: Status updates within 100ms of phase changes
3. **Backward Compatible**: Traditional output available via flag or non-TTY
4. **Error Visibility**: Failed packages show logs immediately
5. **Performance**: No significant overhead vs. current implementation
6. **Cross-platform**: Works on macOS (Darwin) and Linux

## Assumptions

- Users want phase-level granularity (based on Q10 answer)
- Fixed-position display is preferred over scrolling (based on Q9)
- Current parallel execution strategy remains unchanged (based on Q7)
- TTY detection is reliable for environment detection
- ANSI escape sequences are supported in target terminals
