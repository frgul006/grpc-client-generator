# Context Findings - Preflight UI Enhancement

## Current Implementation Analysis

### File Structure
- Main implementation: `cli/lib/preflight.sh`
- Common utilities: `cli/lib/common.sh` (contains color codes and logging functions)
- Current implementation spans lines 48-95 (_run_single_verify) and 140-194 (main handler)

### Current Flow
1. **Discovery Phase**: Finds all packages with `verify` scripts
2. **Staging**: Separates packages into producers (core libs) and consumers
3. **Execution**: 
   - Stage 1: Producers run sequentially
   - Stage 2: Consumers run in parallel (using CPU core count)
4. **Output**: Uses `tail -f` to stream live logs with package prefixes
5. **Results**: Shows summary with success/failure counts

### Technical Details

#### Current Output Mechanism
- Uses `tail -f` on a central log file to show last 20 lines
- Each package output is prefixed with `[package-name]`
- Attempts to use `stdbuf` or `gstdbuf` for unbuffered output
- Falls back to `sed` with platform-specific flags

#### Verify Scripts Pattern
Each package has a `verify` script that typically runs:
- `npm run lint` - ESLint checks
- `npm run format:check` - Prettier formatting
- `npm run check:types` - TypeScript type checking  
- `npm run check:unused` - Dependency checks (for libs)
- `npm run check:spelling` - Spell checking (for libs)
- `npm run build` - Build process
- `npm run test` - Unit tests
- `npm run test:e2e` - E2E tests (for APIs)

#### Existing UI Elements
- Color codes already defined: RED, GREEN, YELLOW, BLUE, CYAN, NC
- Emoji usage in logging: ℹ️ ✅ ⚠️ ❌ 🔄 🔍
- Timestamp format: `[HH:MM:SS]`
- Cursor management: `tput cnorm` to restore cursor

### Integration Points

#### Files to Modify
1. **cli/lib/preflight.sh**:
   - Lines 48-95: `_run_single_verify` function
   - Lines 140-194: Main display logic
   - Add new status rendering functions

2. **cli/lib/common.sh**:
   - May need additional ANSI escape sequences
   - Could add status update functions

### Similar Features Analyzed
- No existing dashboard-style UI in the codebase
- Setup command uses simple progress logging
- All current output is line-based streaming

### Technical Constraints
1. **Bash Compatibility**: Must work with bash on Darwin/macOS and Linux
2. **Dependencies**: Can rely on standard Unix tools (awk, sed, tput)
3. **Parallel Execution**: Must handle concurrent package updates
4. **Error Preservation**: Must maintain full error logs
5. **CI/CD Compatibility**: Must detect non-TTY and fall back to verbose

### Patterns to Follow
1. Use existing color codes and emoji patterns
2. Follow modular function structure
3. Maintain error handling with `set -Eeuo pipefail`
4. Use trap for cleanup (already implemented)
5. Follow existing logging function patterns

### Implementation Opportunities
1. **Status Tracking**: Need to track phase transitions (lint→format→build→test)
2. **ANSI Manipulation**: Use escape sequences for in-place updates
3. **State Management**: Track package states in temp files
4. **Progress Parsing**: Parse npm output to detect phase changes
5. **Fallback Logic**: Detect TTY with `[[ -t 1 ]]` check