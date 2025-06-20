# Add `lab preflight` Command for Parallel Package Verification

## Problem

The monorepo contains multiple packages that each have comprehensive `verify` scripts for quality assurance (linting, type checking, testing, building). Currently, developers and CI/CD pipelines must manually run verification across all packages, which is:

- **Time-consuming**: Running verification sequentially takes much longer than necessary
- **Error-prone**: Easy to forget checking certain packages or running incomplete validation
- **Inconsistent**: No standardized way to run pre-commit or CI verification across the entire monorepo

There are currently 4 packages with verify scripts:
- `services/example-service` 
- `libs/grpc-client-generator`
- `apis/user-api`
- `apis/product-api`

## Solution

Implement a `lab preflight` command that automatically discovers all packages with `verify` scripts and runs them in parallel, providing a single command for comprehensive monorepo validation.

### Key Features

- **Dynamic package discovery**: Uses `find` + `jq` to robustly detect packages with verify scripts
- **Parallel execution**: Leverages all CPU cores for maximum performance using `xargs`
- **Clean output management**: Isolates output per package with clear success/failure summary
- **CI/CD integration**: Proper exit codes and error aggregation for automated workflows
- **Cross-platform compatibility**: Works on both Linux and macOS development environments

### Event Flow
1. Command discovers packages with verify scripts → 2. Runs `npm run verify` in parallel → 3. Aggregates results → 4. Reports summary with proper exit code

## Implementation Plan

### Task 1: Add Command Infrastructure

**Location:** `cli/lib/commands.sh`

#### 1.1: Extend Argument Parser
```bash
# Add to parse_args() function around line 64
preflight)
    # Preflight command doesn't support --keep-state
    if [[ "$KEEP_STATE_MODE" == true ]]; then
        log_error "Command '$COMMAND' does not support --keep-state flag"
        exit 1
    fi
    ;;
```

#### 1.2: Add Command Handler
```bash
# Add to handle_command() function around line 104
preflight)
    handle_preflight_command
    ;;
```

### Task 2: Implement Core Functionality

**Location:** `cli/lib/commands.sh`

#### 2.1: Cross-Platform CPU Detection Helper
```bash
# Add utility function for cross-platform CPU core detection
get_cpu_cores() {
    # Most portable method across Linux and macOS
    if command -v getconf &>/dev/null; then
        getconf _NPROCESSORS_ONLN 2>/dev/null || echo "4"
    else
        # Fallback methods
        if command -v nproc &>/dev/null; then
            nproc
        elif command -v sysctl &>/dev/null; then
            sysctl -n hw.ncpu 2>/dev/null || echo "4"
        else
            echo "4"  # Conservative default
        fi
    fi
}
```

#### 2.2: Single Package Verification Function
```bash
# Export function for xargs subshells
export -f _run_single_verify

_run_single_verify() {
    local package_dir=$1
    local package_name=$(basename "$package_dir")
    local temp_dir="$2"
    local log_file="${temp_dir}/logs/${package_name}.log"
    local results_dir="${temp_dir}/results"
    
    # Change to directory and run verify, capturing all output
    if (cd "$package_dir" && npm run verify) > "$log_file" 2>&1; then
        # Success: create success marker and clean log
        touch "${results_dir}/${package_name}.success"
        rm -f "$log_file"
        echo "✅ SUCCESS: ${package_name}"
    else
        # Failure: create failure marker with exit code
        local exit_code=$?
        echo "$exit_code" > "${results_dir}/${package_name}.failure"
        echo "❌ FAILURE: ${package_name} (Exit code: $exit_code)"
    fi
}
```

#### 2.3: Main Preflight Command Handler
```bash
handle_preflight_command() {
    log_info "🚀 Running preflight verification across all packages..."
    
    # Dependency checks
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for preflight command but not installed"
        log_info "💡 Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi
    
    if ! command -v npm &>/dev/null; then
        log_error "npm is required for preflight command but not installed"
        exit 1
    fi
    
    # Create temporary working directory
    local temp_dir
    temp_dir=$(mktemp -d)
    local results_dir="${temp_dir}/results"
    local log_dir="${temp_dir}/logs"
    mkdir -p "$results_dir" "$log_dir"
    
    # Ensure cleanup on exit
    trap "rm -rf '$temp_dir'" EXIT
    
    # Export variables for subshells
    export TEMP_DIR="$temp_dir"
    export LOG_DIR="$log_dir"
    export RESULTS_DIR="$results_dir"
    
    # Discover packages with verify scripts
    log_info "🔍 Discovering packages with verify scripts..."
    
    local packages_with_verify=()
    while IFS= read -r -d '' pkg_json; do
        if jq -e '.scripts.verify' "$pkg_json" > /dev/null 2>&1; then
            local package_dir
            package_dir=$(dirname "$pkg_json")
            packages_with_verify+=("$package_dir")
        fi
    done < <(find "$REPO_ROOT" -type f -name "package.json" -not -path "*/node_modules/*" -print0)
    
    if [[ ${#packages_with_verify[@]} -eq 0 ]]; then
        log_warning "No packages with verify scripts found"
        return 0
    fi
    
    log_info "📦 Found ${#packages_with_verify[@]} packages with verify scripts"
    
    # Run verification in parallel
    local cpu_cores
    cpu_cores=$(get_cpu_cores)
    log_info "⚡ Running verification in parallel (${cpu_cores} cores)"
    
    printf '%s\n' "${packages_with_verify[@]}" | \
        xargs -P "$cpu_cores" -I {} bash -c '_run_single_verify "{}" "$TEMP_DIR"'
    
    # Aggregate and report results
    local overall_status=0
    local success_count=0
    local failure_count=0
    
    echo
    log_info "📊 PREFLIGHT SUMMARY"
    echo "================================"
    
    # Report successes
    for result_file in "$results_dir"/*.success; do
        [[ -e "$result_file" ]] || continue
        local package_name
        package_name=$(basename "$result_file" .success)
        echo "✅ SUCCESS: ${package_name}"
        ((success_count++))
    done
    
    # Report failures with logs
    for result_file in "$results_dir"/*.failure; do
        [[ -e "$result_file" ]] || continue
        overall_status=1
        local package_name
        package_name=$(basename "$result_file" .failure)
        local exit_code
        exit_code=$(cat "$result_file")
        echo "❌ FAILURE: ${package_name} (Exit: $exit_code)"
        
        # Show failure log
        local log_file="${log_dir}/${package_name}.log"
        if [[ -f "$log_file" ]]; then
            echo "--- Log for ${package_name} ---"
            cat "$log_file"
            echo "--------------------------------"
        fi
        ((failure_count++))
    done
    
    echo
    echo "📈 Results: ${success_count} passed, ${failure_count} failed"
    
    if [[ $overall_status -eq 0 ]]; then
        log_success "All preflight checks passed! ✅"
        exit 0
    else
        log_error "Preflight checks failed ❌"
        exit 1
    fi
}
```

### Task 3: Add Help System Integration

**Location:** `cli/lib/help.sh`

#### 3.1: Add Command to Help List
```bash
# Add to show_help() function around line 20
echo "  preflight        Run verify scripts in all packages (parallel)"
```

#### 3.2: Add Specific Help Function
```bash
# Add new help function
show_preflight_help() {
    cat << 'EOF'
Usage: lab preflight [options]

Run 'npm run verify' for all packages in the monorepo that support it.

This command will:
• Automatically discover packages with verify scripts
• Run verification in parallel using all CPU cores
• Provide clear success/failure summary
• Exit with proper status codes for CI/CD integration

The verify script typically runs:
• Linting (eslint)
• Type checking (tsc)
• Code formatting checks (prettier)
• Unit tests (vitest)
• Build validation
• Other quality checks

Options:
  --verbose         Show detailed output (inherited from global flags)

Examples:
  lab preflight     # Run verification on all packages
  lab preflight --verbose    # Run with detailed logging

Exit Codes:
  0    All verifications passed
  1    One or more verifications failed

Notes:
• Requires jq for JSON parsing (install with brew install jq)
• Each package runs in parallel for maximum speed
• Failed package logs are shown automatically
• Perfect for pre-commit hooks and CI/CD pipelines
EOF
}
```

#### 3.3: Integrate with Help Dispatcher
```bash
# Add to show_command_help() function around line 50
preflight)
    show_preflight_help
    ;;
```

### Task 4: Integration Testing

**Test Scenarios:**
1. **All packages pass**: Verify success summary and exit code 0
2. **Some packages fail**: Verify failure logs shown and exit code 1
3. **No packages with verify**: Verify graceful handling
4. **Missing dependencies**: Verify clear error messages for missing jq/npm
5. **Parallel execution**: Verify performance improvement over sequential runs

## Technical Analysis

### Performance Benefits
- **Sequential execution**: ~4 packages × 30-60 seconds each = 2-4 minutes
- **Parallel execution**: Max(individual package time) = 30-60 seconds
- **Expected speedup**: 3-4x faster verification

### Error Handling Strategy
- **Pre-flight checks**: Validate jq and npm availability
- **Robust temp management**: Automatic cleanup with trap handlers  
- **Aggregate exit codes**: Fail-fast behavior for CI/CD
- **Clear output isolation**: No interleaved output from parallel processes

### Cross-Platform Compatibility
- **CPU detection**: `getconf _NPROCESSORS_ONLN` works on both Linux and macOS
- **JSON parsing**: `jq` is the gold standard for reliable JSON parsing
- **Temp directories**: `mktemp -d` is POSIX compliant
- **Process management**: `xargs -P` is widely supported

## Risk Analysis & Mitigation

### High Risk: Resource Exhaustion
- **Problem**: Running all packages in parallel could overwhelm system resources
- **Mitigation**: Limit concurrency to CPU core count using `get_cpu_cores()`

### Medium Risk: Package Dependencies
- **Problem**: Some packages might need others to be built first
- **Mitigation**: Each package's verify script should be self-contained. If dependencies exist, they should be handled within individual verify scripts

### Low Risk: Output Management
- **Problem**: Large log outputs could consume significant disk space
- **Mitigation**: 
  - Clean up successful package logs immediately
  - Use temporary directories that are automatically cleaned
  - Only preserve failure logs for debugging

### Low Risk: Missing jq Dependency
- **Problem**: jq might not be installed on developer machines
- **Mitigation**: Clear error message with installation instructions

## Success Criteria

- ✅ Single `lab preflight` command verifies entire monorepo
- ✅ Parallel execution provides significant performance improvement
- ✅ Clear success/failure reporting with failure logs
- ✅ Proper exit codes for CI/CD integration
- ✅ Cross-platform compatibility (macOS + Linux)
- ✅ Integration with existing CLI help system
- ✅ Robust error handling and dependency validation
- ✅ No zombie processes or temp file leaks

## Location References

- `cli/lib/commands.sh:15-97` - Argument parsing (parse_args function)
- `cli/lib/commands.sh:104-160` - Command dispatching (handle_command function)
- `cli/lib/commands.sh:450+` - New preflight handler functions (end of file)
- `cli/lib/help.sh:20+` - Help system integration
- `cli/lib/common.sh` - Logging utilities (log_info, log_success, log_error)