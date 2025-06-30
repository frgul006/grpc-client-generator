# Context Findings

**Phase:** Targeted Context Gathering Complete  
**Analysis Date:** 2025-06-29T23:50:00Z

## Previous Requirements Analysis

### Original Specification Issues
From `/requirements/2025-06-29-2306-core-generator/06-requirements-spec.md`:
- **Status**: NOT READY FOR IMPLEMENTATION
- **Critical Gaps**: 4 blocking issues, 1 high priority
- **Risk Level**: HIGH

### Discovery Answers Impact
Based on new discovery answers:
1. **No backward compatibility** → Clean interface redesign acceptable
2. **No auto-dependency installation** → Explicit package.json updates required
3. **Yes to incremental compilation** → Performance feature must be included
4. **Yes to retry mechanisms** → Error handling with robustness
5. **Yes to integration testing** → Real gRPC service validation required

## Specific Files Requiring Updates

### Primary Implementation Files
- **`/libs/grpc-client-generator/src/index.ts`** 
  - Current: Placeholder with `GeneratorOptions { services: ServiceConfig[] }`
  - Required: Complete rewrite with file-centric interface
  - Impact: Breaking change acceptable per discovery answers

- **`/libs/grpc-client-generator/package.json`**
  - Missing: `ts-proto` (~2.7.5 - latest 2024/2025)
  - Missing: `ts-morph` (latest stable version)
  - Missing: `grpc-tools` or equivalent for protoc binary
  - Action: Add as dependencies, not devDependencies

### Integration Points
- **`/cli/lib/preflight.sh`** - Build verification pipeline integration
- **Consumer packages** - `/apis/product-api/src/generated/` output directories

## Technical Implementation Requirements

### Dependency Strategy
**Required Dependencies** (based on research):
```json
{
  "dependencies": {
    "ts-proto": "~2.7.5",
    "ts-morph": "^23.0.0",
    "grpc-tools": "^1.12.4"
  }
}
```

**Rationale**:
- `ts-proto` 2.7.5: Latest stable with @bufbuild/protobuf migration
- `ts-morph`: TypeScript AST manipulation wrapper
- `grpc-tools`: Provides protoc binary dependency

### Enhanced Interface Design
**New GeneratorOptions** (addressing interface conflict):
```typescript
interface GeneratorOptions {
  protoFiles: string[];           // File-centric approach
  outputDir: string;              // Clear output destination
  incremental?: boolean;          // Performance feature from Q3
  retryConfig?: RetryConfig;      // Robustness from Q4
  forwardHeaders?: string[];      
  enableLogging?: boolean;        
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
  errorTransform?: boolean;       
  tsProtoOptions?: Record<string, any>;
}

interface RetryConfig {
  maxAttempts: number;
  backoffMs: number;
  retryableErrors?: string[];
}
```

### Error Handling Strategy
**Transactional Generation** (addressing critical gap):
- Temporary file generation → validation → atomic move
- Retry mechanism for transient protoc/ts-proto failures
- Clear error messages with actionable guidance
- Rollback capability for partial failures

### Testing Strategy Requirements
**Multi-Layer Validation** (from Q5 - integration testing):
1. **Unit Tests**: AST transformation functions in isolation
2. **Integration Tests**: Generated clients vs real gRPC services
3. **Snapshot Tests**: Generated code structure validation
4. **Performance Tests**: Incremental compilation benchmarks

### Performance Features
**Incremental Compilation** (from Q3):
- File change detection via timestamps/hashes
- Dependency graph for selective regeneration
- Caching strategy for AST transformations
- Memory usage optimization for large batches

## Build Integration Analysis

### Lab Preflight Compatibility
- **Existing**: Parallel verification across packages
- **Required**: Generator integration without breaking existing flows
- **Strategy**: Add generator step before verification, not during

### Verification Pipeline
Current `/cli/lib/preflight.sh` pattern:
- Supports parallel execution
- Includes lint, type-check, format validation
- Must accommodate generated file validation

## Related Features Analysis

### Similar Patterns in Codebase
- **Build-time generation**: Already used in APIs packages
- **TypeScript compilation**: Existing tsup/tsc integration
- **Verification workflows**: Established patterns in preflight

### Integration Constraints
- **Node.js version**: >=18.3.0 (from package.json engines)
- **Package manager**: npm@10.9.2 requirement
- **TypeScript**: 5.8.2 compatibility required

## Next Phase Requirements

### Critical Decisions Needed
1. **Exact dependency versions** - Pin to tested compatibility matrix
2. **Incremental compilation scope** - File-level vs function-level tracking
3. **Retry strategy specifics** - Which errors are retryable
4. **Integration test scope** - Mock vs real service requirements
5. **Performance benchmarks** - Acceptable limits for batch processing

### Implementation Readiness Blockers
**Resolved by this analysis**:
- ✅ Interface design direction (clean break acceptable)
- ✅ Dependency identification (ts-proto, ts-morph, grpc-tools)
- ✅ Performance requirements (incremental compilation)
- ✅ Testing approach (integration + unit + snapshot)

**Still requiring expert detail questions**:
- Specific retry configuration parameters
- Integration test service requirements
- Incremental compilation implementation strategy
- Error handling granularity
- Performance benchmark thresholds