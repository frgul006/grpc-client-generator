# Split large CLI shell script modules

## Problem

Several CLI modules have grown too large, making them difficult to navigate and maintain:
- commands.sh: 580 lines
- setup.sh: 564 lines  
- state.sh: 455 lines

## Solution

Split each module by logical concerns:
- commands.sh: Separate argument parsing from command dispatch
- setup.sh: Extract OS-specific installation logic into separate modules
- state.sh: Separate state persistence from validation logic

## Location

- `cli/lib/commands.sh` - 580 lines
- `cli/lib/setup.sh` - 564 lines
- `cli/lib/state.sh` - 455 lines