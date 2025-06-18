# Ticket 05: Error Recovery Enhancement

## Epic/Scope
setup-script

## What
Enhance setup.sh with robust error recovery mechanisms, retry logic for transient failures, and improved error handling to increase reliability in unstable network conditions and edge cases.

## Why
- **Reliability**: Network-dependent operations often fail due to transient issues
- **User Experience**: Reduce manual intervention required when setup encounters temporary problems
- **Production Readiness**: Make setup script more suitable for automated environments
- **Robustness**: Handle edge cases and partial failure states gracefully
- **Debugging**: Better error messages and recovery suggestions

Current setup.sh can fail on temporary network issues, Docker daemon startup delays, or race conditions, requiring manual restart of the entire process.

## How

### 1. Retry Mechanism Framework

#### Generic Retry Function
```bash
# Retry a command with exponential backoff
# Arguments:
#   $1 - max attempts
#   $2 - base delay (seconds)
#   $3+ - command to execute
retry_with_backoff() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        
        local delay=$((base_delay * attempt))
        log_warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}
```

### 2. Network Operation Enhancements

#### Tool Installation Retry
- Retry brew/package manager operations
- Handle repository update failures
- Implement fallback installation methods

#### Docker Operations Retry
- Retry Docker network creation
- Handle Docker daemon startup delays
- Retry container operations with backoff

#### Verdaccio Registry Retry
- Retry health checks with exponential backoff
- Handle startup race conditions
- Implement graceful degradation

### 3. Partial State Recovery

#### Checkpoint System
- Track completion of major setup phases
- Allow resuming from last successful checkpoint
- Provide `--resume` flag for recovery

#### State Validation
- Verify each component is properly configured before proceeding
- Detect and recover from partial installations
- Handle interrupted setup gracefully

### 4. Enhanced Error Reporting

#### Structured Error Context
```bash
report_error() {
    local error_code="$1"
    local component="$2"
    local operation="$3"
    local suggestion="$4"
    
    log_error "Error $error_code in $component during $operation"
    log_info "Suggestion: $suggestion"
    log_info "Run './setup.sh --status' to check current state"
}
```

#### Recovery Suggestions
- Provide specific next steps for common failures
- Suggest manual intervention when automatic retry fails
- Link to troubleshooting documentation

### 5. Timeout Management
- Add configurable timeouts for long-running operations
- Implement proper cleanup when operations time out
- Provide user feedback during long waits

### 6. Graceful Degradation
- Continue setup when non-critical components fail
- Mark components as "degraded" rather than failing completely
- Provide warnings and recovery instructions

## Definition of Done

- [ ] `retry_with_backoff()` function implemented and tested
- [ ] Network-dependent operations use retry logic:
  - [ ] Tool installation (brew, package managers)
  - [ ] Docker operations (network creation, container startup)
  - [ ] Verdaccio health checks
  - [ ] npm install operations
- [ ] Checkpoint system allows resuming interrupted setup:
  - [ ] `--resume` flag implemented
  - [ ] State tracking for major phases
  - [ ] Validation of existing state before proceeding
- [ ] Enhanced error reporting provides:
  - [ ] Structured error context with component and operation
  - [ ] Specific recovery suggestions
  - [ ] Links to relevant documentation
- [ ] Timeout management for long-running operations:
  - [ ] Configurable timeout values
  - [ ] Proper cleanup on timeout
  - [ ] User feedback during waits
- [ ] Graceful degradation allows partial success:
  - [ ] Non-critical failures don't stop entire setup
  - [ ] "Degraded" status reporting
  - [ ] Clear indication of what needs manual intervention
- [ ] Documentation updated with error recovery procedures
- [ ] All retry mechanisms respect user interruption (Ctrl+C)

## Priority
Medium

## Estimated Effort
Large (4-5 hours)

## Dependencies
- Ticket 03 (versioning) for better error reporting context
- Ticket 04 (documentation) for recovery procedure docs

## Risks
- Increased script complexity
- Longer setup times due to retry delays
- Potential for infinite retry loops if not properly bounded
- User confusion about partial success states