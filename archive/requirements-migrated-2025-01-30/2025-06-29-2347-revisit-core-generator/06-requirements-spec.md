# Requirements Specification: Core Generator (Revised)

**Generated:** 2025-06-29T23:55:00Z  
**Status:** READY FOR IMPLEMENTATION  
**Previous Status:** NOT READY - Critical gaps addressed  
**Parent Requirement:** 2025-06-29-2306-core-generator

## Overview

This specification addresses the critical implementation gaps identified in the original core generator requirements. Based on comprehensive analysis and targeted decision-making, this revision resolves all blocking issues and provides a complete, implementable specification for the gRPC client generator.

**Problem Statement**: The original specification contained 4 blocking issues and 1 high-priority gap that prevented safe implementation. This revision addresses each gap with specific design decisions and implementation guidance.

**Solution Summary**: Implement a production-ready TypeScript AST post-processor with clean interface design, explicit dependency management, robust error handling with retries, comprehensive testing strategy, and incremental compilation performance features.

## Critical Gaps Resolved

### ✅ Interface Design Conflict (CRITICAL → RESOLVED)
**Original Issue**: Mismatch between existing `GeneratorOptions { services: ServiceConfig[] }` and spec requirements  
**Resolution**: Clean break acceptable - implement file-centric interface with breaking change  
**Decision Source**: Discovery Q1 - No backward compatibility required

### ✅ Missing Critical Dependencies (CRITICAL → RESOLVED)
**Original Issue**: Required libraries not specified in dependency chain  
**Resolution**: Explicit dependency management with version coordination  
**Decision Source**: Discovery Q2 - No auto-installation, explicit package.json updates

### ✅ Incomplete Error Handling Strategy (CRITICAL → RESOLVED)
**Original Issue**: No failure recovery or error handling defined  
**Resolution**: Robust retry mechanisms with transactional generation  
**Decision Source**: Discovery Q4 - Yes to retry mechanisms for reliability

### ✅ Missing Testing Strategy (CRITICAL → RESOLVED)
**Original Issue**: No validation approach for generated code correctness  
**Resolution**: Multi-layer testing with mock integration and real e2e validation  
**Decision Source**: Discovery Q5 + Detail Q4 - Integration testing with mocks, e2e with real services

### ✅ Performance and Scale Considerations (HIGH → RESOLVED)
**Original Issue**: No guidance for large-scale usage  
**Resolution**: Incremental compilation with dependency tracking  
**Decision Source**: Discovery Q3 - Performance critical for production adoption

## Functional Requirements

### R1: File-Centric Code Generation
- **Source**: Discovery analysis + interface conflict resolution
- **Requirement**: Generate TypeScript client code using file-centric configuration
- **Implementation**: Process array of `.proto` files with single output directory
- **Interface**: `GeneratorOptions { protoFiles: string[], outputDir: string, ... }`

### R2: Explicit Dependency Management
- **Source**: Missing dependencies gap resolution
- **Requirement**: Explicit declaration of all required dependencies in package.json
- **Implementation**: Pin ts-proto to consumer library version, add ts-morph and grpc-tools
- **Dependencies**: Consumer-version alignment for ts-proto compatibility

### R3: Robust Error Handling with Retries
- **Source**: Discovery Q4 + Detail Q1 - retry mechanisms for external failures
- **Requirement**: Implement retry logic for protoc/ts-proto command failures only
- **Implementation**: Transactional generation with retry for external process failures
- **Scope**: External command failures, not AST processing logic errors

### R4: Incremental Compilation with Dependency Tracking
- **Source**: Discovery Q3 + Detail Q2 - performance critical with import tracking
- **Requirement**: Track proto file dependencies and regenerate selectively
- **Implementation**: Dependency graph analysis with timestamp/hash-based change detection
- **Scope**: Import changes trigger downstream regeneration

### R5: Comprehensive Testing Strategy
- **Source**: Discovery Q5 + Detail Q4 - integration + e2e validation
- **Requirement**: Multi-layer testing with mock integration and real service e2e
- **Implementation**: Unit tests (AST), integration tests (mocks), e2e tests (real services)
- **Validation**: Generated code correctness across all layers

## Technical Requirements

### Interface Design (Breaking Change)
```typescript
interface GeneratorOptions {
  protoFiles: string[];                    // File-centric approach
  outputDir: string;                       // Clear output destination  
  incremental?: boolean;                   // Performance feature
  retryConfig?: RetryConfig;               // Robustness configuration
  forwardHeaders?: string[];               // Header forwarding list
  enableLogging?: boolean;                 // Logging feature toggle
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
  errorTransform?: boolean;                // Error transformation
  tsProtoOptions?: Record<string, any>;    // Pass-through options
}

interface RetryConfig {
  maxAttempts: number;                     // Retry attempts for external failures
  backoffMs: number;                       // Backoff delay between retries  
  retryableErrors?: string[];              // Specific error patterns to retry
}
```

### Dependency Strategy
**Required Package.json Updates**:
```json
{
  "dependencies": {
    "ts-proto": "match-consumer-version",
    "ts-morph": "^23.0.0", 
    "grpc-tools": "^1.12.4"
  }
}
```

**Version Coordination** (Detail Q3):
- ts-proto: Pin to whatever consuming library is using
- ts-morph: Latest stable for TypeScript AST manipulation
- grpc-tools: Provides protoc binary dependency

### Error Handling Architecture
**Transactional Generation Process**:
1. **Pre-validation**: Check proto file existence and syntax
2. **Temporary Generation**: Generate to temp directory
3. **Validation**: Verify generated code syntax and structure
4. **Atomic Move**: Move validated files to final destination
5. **Rollback**: Clean up on any failure

**Retry Strategy** (Detail Q1 - external failures only):
- **Scope**: protoc command failures, file system locks, temporary network issues
- **Excluded**: AST parsing errors, code generation logic failures
- **Configuration**: Configurable attempts, backoff timing, error pattern matching

### Incremental Compilation Design
**Dependency Tracking** (Detail Q2 - import-aware):
- **Proto Import Analysis**: Parse import statements to build dependency graph
- **Change Detection**: Timestamp and content hash comparison
- **Selective Regeneration**: Only regenerate files with changed dependencies
- **Cache Strategy**: Store dependency metadata for quick comparison

**Performance Features**:
- File-level change detection via timestamps/hashes
- Import dependency graph for cascade regeneration
- AST transformation result caching
- Memory-efficient batch processing (no artificial limits per Detail Q5)

### Testing Strategy Implementation
**Multi-Layer Validation** (Detail Q4 - mocks for integration):

1. **Unit Tests**: 
   - AST transformation functions in isolation
   - TypeScript parsing and filtering logic
   - Enhancement wrapper generation

2. **Integration Tests**:
   - Generated client code with mock gRPC services
   - Header forwarding with mock context
   - Error handling with simulated failures

3. **End-to-End Tests**:
   - Generated clients against real gRPC services
   - Full pipeline validation (proto → generated → runtime)
   - Performance benchmarks for incremental compilation

4. **Snapshot Tests**:
   - Generated code structure validation
   - Regression detection for output changes
   - AST transformation result consistency

## Implementation Components

### Primary Files to Modify
- **`/libs/grpc-client-generator/src/index.ts`**: Complete rewrite with new interface
- **`/libs/grpc-client-generator/package.json`**: Add required dependencies
- **Test files**: Comprehensive test suite implementation

### New Components to Create
1. **Proto Dependency Analyzer**: Import graph building and change detection
2. **Retry Manager**: External failure retry logic with configurable policies  
3. **Incremental Compiler**: Change detection and selective regeneration
4. **Test Infrastructure**: Mock services and e2e validation framework

### Build Integration Strategy
- **Lab Preflight Compatibility**: Add generator step before existing verification
- **Verification Pipeline**: Include generated file validation in existing flows
- **Performance Integration**: Incremental compilation for development workflow

## Acceptance Criteria

### AC1: Interface Migration Complete
- [ ] New file-centric `GeneratorOptions` interface implemented
- [ ] Breaking change properly documented and versioned
- [ ] All existing placeholder code replaced with functional implementation

### AC2: Dependency Management Resolved  
- [ ] ts-proto version coordinated with consumer libraries
- [ ] ts-morph and grpc-tools added as explicit dependencies
- [ ] No auto-installation logic, explicit package.json requirements

### AC3: Error Handling and Retry Implementation
- [ ] Transactional generation prevents partial file corruption
- [ ] Retry logic handles external process failures with configurable parameters
- [ ] AST processing failures fail fast without retry attempts

### AC4: Incremental Compilation Working
- [ ] Proto import dependencies tracked and cached
- [ ] Only changed files and their dependents regenerated
- [ ] Performance improvement demonstrated on multi-file proto sets

### AC5: Comprehensive Testing Validation
- [ ] Unit tests cover AST transformation functions
- [ ] Integration tests use mock gRPC services
- [ ] End-to-end tests validate against real services
- [ ] Snapshot tests prevent regression in generated code structure

### AC6: Production Readiness
- [ ] Generated code passes existing lint, format, and type-check rules
- [ ] Build integration works with `lab preflight` verification pipeline
- [ ] Performance scales appropriately without artificial batch size limits
- [ ] Documentation includes clear usage examples and migration guide

## Migration Strategy

### Breaking Change Management
1. **Version Bump**: Major version increment for interface breaking change
2. **Migration Guide**: Document transition from service-centric to file-centric configuration
3. **Deprecation**: Clear timeline for old interface removal if needed

### Implementation Phases
1. **Phase 1**: Interface redesign and dependency updates
2. **Phase 2**: Error handling and retry implementation  
3. **Phase 3**: Incremental compilation features
4. **Phase 4**: Comprehensive testing infrastructure
5. **Phase 5**: Build integration and performance validation

## Implementation Readiness

**Status**: ✅ **READY FOR IMPLEMENTATION**

**All Blocking Issues Resolved**:
- ✅ Interface design conflict → Clean break with file-centric approach
- ✅ Missing dependencies → Explicit ts-proto/ts-morph/grpc-tools requirements
- ✅ Error handling gaps → Transactional generation with external retry logic
- ✅ Testing strategy → Multi-layer validation with mocks and real services
- ✅ Performance concerns → Incremental compilation with dependency tracking

**Risk Assessment**: **LOW** - All critical decisions made, implementation path clear

**Next Steps**: Begin implementation starting with interface redesign and dependency updates, followed by systematic implementation of error handling, incremental compilation, and testing infrastructure.