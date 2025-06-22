# Enhance Preflight UI with Better Progress Feedback

## Problem

The current preflight command creates **cognitive overload** rather than confidence:
- **Information overload**: Shows every line from npm scripts (build paths, file counts, timing info)
- **No progress context**: Can't tell if 30 seconds of output means 10% or 90% complete
- **Visual fatigue**: All text looks the same, no hierarchy or importance signals
- **Mixed contexts**: Output from 3 parallel packages interleaved randomly
- **Uncertainty**: No clear indication when packages start/complete phases
- **Cognitive load**: Developer must mentally parse and filter what's important

Analysis shows 90% of current output is "noise" level information that developers don't need for decision-making.

## Solution: Transform to Status Dashboard

**Key Insight**: Developers want to see packages as atomic units progressing through states, not streams of tool output.

### Recommended Experience Flow
```bash
🚀 Preflight Verification (4 packages)

Stage 1: Core Libraries  
✅ grpc-client-generator (✓lint ✓types ✓build ✓test) 2.1s

Stage 2: Services (parallel)
🟡 user-api (✓lint ✓format →build)  
🟡 product-api (✓lint →format)
⏳ example-service (pending)
```

### Implementation Strategy
1. **Progressive Status Display** - Show packages transitioning through states with visual indicators
2. **Smart Filtering** - Hide verbose tool output, show only phase transitions and failures  
3. **In-place Updates** - Replace streaming logs with live status updates using ANSI escape codes
4. **Progressive Disclosure** - Summary view with detailed logs available on failure

### Technical Changes
- Modify `_run_single_verify` to emit structured status updates instead of raw output
- Parse npm script phases to show meaningful progress states  
- Create status renderer that updates in-place
- Maintain full error logging while filtering successful operations

## Location

- `cli/lib/preflight.sh:L48-L95` (enhance \_run_single_verify for structured status updates)
- `cli/lib/preflight.sh:L140-L194` (replace streaming log with status dashboard)
- Add new status rendering functions for in-place updates

## Expected Outcome

Transform preflight from a "verbose process monitor" into a "confident status dashboard" that makes developers think "ooh, that's smooth" by providing clarity and control without information overwhelm.
