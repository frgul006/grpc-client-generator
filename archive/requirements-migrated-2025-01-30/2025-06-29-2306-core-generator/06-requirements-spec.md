# Requirements Specification: Core Generator

Generated: 2025-06-29T23:35:00Z
Updated: 2025-06-29T23:45:00Z
Status: Complete with technical analysis validation
**Implementation Status: NOT READY - Critical gaps identified during analysis**

## Overview

The core gRPC client generator is currently non-functional, containing only placeholder code despite being the project's main value proposition. This specification defines the requirements for implementing a TypeScript AST post-processor that generates enhanced gRPC client code with built-in observability features.

**Problem Statement**: The `grpc-client-generator` library at `/libs/grpc-client-generator/src/index.ts` contains only `console.log` statements, making it unusable for actual client generation.

**Solution Summary**: Implement a post-processing tool that takes ts-proto generated output, filters for client-only components, and injects enhancement layers for header forwarding, logging, and error handling.

## Detailed Requirements

### Functional Requirements

#### R1: Client-Side Code Generation
- **Source**: Discovery Q1 - Should generate client-side gRPC stubs for consuming services
- **Requirement**: Generate TypeScript client code from Protocol Buffer definitions
- **Implementation**: Process `.proto` files through ts-proto pipeline and extract client-relevant components

#### R2: ts-proto Pipeline Integration  
- **Source**: Discovery Q2 - Should support the same ts-proto pipeline currently used
- **Requirement**: Maintain compatibility with existing protoc + ts-proto toolchain
- **Implementation**: Execute standard `protoc --plugin=protoc-gen-ts_proto` commands and post-process output

#### R3: Built-in Enhancement Features
- **Source**: Discovery Q3 - Should include header forwarding, logging, and error handling
- **Requirement**: Generate enhanced client wrappers with observability features
- **Implementation**: Create decorator pattern wrapper classes that implement the same client interface

#### R4: Batch Processing Support
- **Source**: Discovery Q4 - Should support multiple proto files in single operation
- **Requirement**: Process multiple `.proto` files efficiently in one generator invocation
- **Implementation**: Accept array of proto file paths and coordinate parallel processing

#### R5: Build-Time Generation
- **Source**: Discovery Q5 - Generate build-time client-side files, not standalone packages
- **Requirement**: Output enhanced client code directly to consumer package directories
- **Implementation**: Generate files into specified output directories during build process

### Technical Requirements

#### Affected Files
- **Primary Implementation**: `/libs/grpc-client-generator/src/index.ts` (currently placeholder)
- **Generated Output**: Consumer package directories (e.g., `/apis/product-api/src/generated/`)
- **Build Integration**: `/cli/lib/preflight.sh` (verification pipeline)

#### New Components
1. **TypeScript AST Processor**: Parse and transform ts-proto generated code
2. **Client Component Filter**: Extract client-only types and interfaces  
3. **Enhancement Wrapper Generator**: Create decorator pattern classes
4. **Batch Coordinator**: Handle multiple proto file processing
5. **Build Pipeline Integration**: Connect with existing verification system

#### Code Generation Strategy
- **Input**: ts-proto generated TypeScript files containing both client and server code
- **Processing**: AST transformation using tools like `ts-morph`
- **Output**: Client-only enhanced TypeScript files

#### Component Filtering Logic
**Keep (Client-Required)**:
- Interface definitions (`Product`, `GetProductRequest`, etc.)
- MessageFns with encode/decode/fromJSON/toJSON
- `ProductServiceClient` interface and types
- `makeGenericClientConstructor` factory functions
- Client-side imports from `@grpc/grpc-js`

**Remove (Server-Only)**:
- `ProductServiceServer` interface
- `handleUnaryCall` server handler types
- Server-side service definitions

#### Enhancement Layer Architecture
```typescript
// Generated wrapper pattern
export class EnhancedProductServiceClient implements ProductServiceClient {
  constructor(
    private client: ProductServiceClient, 
    private logger?: Logger,
    private headerForwarder?: HeaderForwarder
  ) {}
  
  async getProduct(request: GetProductRequest): Promise<GetProductResponse> {
    // 1. Extract headers from AsyncLocalStorage context
    // 2. Log request with correlation ID
    // 3. Forward headers via gRPC metadata
    // 4. Execute client call with error handling
    // 5. Log response and return
  }
}
```

### Implementation Notes

#### TypeScript AST Processing Approach
- Use `ts-morph` or similar TypeScript compiler API
- Parse generated ts-proto files as TypeScript AST
- Filter nodes based on client/server classification
- Generate new wrapper classes that implement client interfaces
- Preserve all type information and imports

#### Header Forwarding Strategy  
- Use Node.js `AsyncLocalStorage` for context propagation
- Avoid passing context through function parameters
- Consumer applications populate context at entry points (HTTP middleware)
- Generated clients read from well-known AsyncLocalStorage instance

#### Build System Integration
- Must work with existing `lab preflight` parallel verification
- Support both development and production build modes
- Integration with existing npm scripts and verification pipeline
- Output files compatible with existing TypeScript compilation

#### Error Handling Enhancement
- Transform gRPC `ServiceError` objects into application-specific errors
- Add request correlation IDs for tracing
- Preserve original error information while adding context
- Support configurable error transformation policies

### Assumptions

**ASSUMED: Logging Configuration**
- Default to console logging if no logger provided
- Support structured logging with correlation IDs
- Configurable log levels (debug, info, warn, error)

**ASSUMED: Header Configuration**
- Default header forwarding list includes: `authorization`, `x-request-id`, `x-correlation-id`
- Support configurable header allow/deny lists
- Headers automatically converted to gRPC metadata format

**ASSUMED: Output File Structure**
- Generated files follow naming pattern: `{service-name}.enhanced.ts`
- Export both original and enhanced client classes
- Include generation timestamp and version in file headers

### Acceptance Criteria

#### AC1: Functional Client Generation
- [ ] Generator processes `.proto` files and produces working TypeScript client code
- [ ] Generated clients successfully make gRPC calls to test services
- [ ] All original ts-proto functionality preserved in generated output

#### AC2: Enhancement Features Working
- [ ] Header forwarding automatically propagates headers from AsyncLocalStorage
- [ ] Request/response logging includes correlation IDs and timing information
- [ ] Error handling transforms gRPC errors with additional context

#### AC3: Build Integration
- [ ] Generator integrates with `lab preflight` verification pipeline
- [ ] Generated code passes existing lint, format, and type-check rules
- [ ] Build process handles multiple proto files efficiently

#### AC4: Developer Experience
- [ ] Generated files include clear "DO NOT EDIT" headers
- [ ] TypeScript compiler provides accurate type checking on generated code
- [ ] Documentation examples show how to use enhanced clients

#### AC5: Batch Processing
- [ ] Single generator invocation processes multiple proto files
- [ ] Cross-proto dependencies resolved correctly
- [ ] Performance scales reasonably with number of input files

### Configuration Interface

```typescript
interface GeneratorOptions {
  protoFiles: string[];           // Input proto file paths
  outputDir: string;              // Output directory for generated files
  forwardHeaders?: string[];      // Headers to forward (default: standard set)
  enableLogging?: boolean;        // Enable request/response logging
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
  errorTransform?: boolean;       // Enable error transformation
  tsProtoOptions?: Record<string, any>; // Pass-through ts-proto options
}
```

This specification provides the foundation for implementing a robust, production-ready gRPC client generator that enhances the existing ts-proto pipeline with essential observability features.

---

## CRITICAL ANALYSIS: IMPLEMENTATION READINESS ASSESSMENT

**Status: NOT READY FOR IMPLEMENTATION**

**Analysis Date**: 2025-06-29T23:45:00Z  
**Risk Level**: HIGH  
**Blocking Issues**: 4 critical, 1 high priority

### BLOCKING ISSUES

#### 1. Interface Design Conflict (CRITICAL)
**Problem**: Fundamental incompatibility between existing code and specification
- **Current Code**: `GeneratorOptions { services: ServiceConfig[] }`
- **Specification**: `GeneratorOptions { protoFiles: string[], outputDir: string, ... }`
- **Impact**: Complete rewrite of existing interface required
- **Resolution Required**: Choose file-centric vs service-centric configuration model

#### 2. Missing Critical Dependencies (CRITICAL)
**Problem**: Required libraries not specified in dependency chain
- **Missing**: `ts-proto` (no version specified)
- **Missing**: `ts-morph` or equivalent AST manipulation library
- **Missing**: `protoc` binary strategy (grpc-tools, protoc-bin-vendored, etc.)
- **Impact**: Cannot implement AST processing without these dependencies
- **Resolution Required**: Update package.json with pinned versions

#### 3. Incomplete Error Handling Strategy (CRITICAL)
**Problem**: No failure recovery or error handling defined
- **Missing**: protoc command failure recovery
- **Missing**: AST parsing error handling
- **Missing**: Partial batch processing failure recovery
- **Missing**: Invalid proto file handling
- **Impact**: Generator could leave codebase in broken state
- **Resolution Required**: Define transactional generation process

#### 4. Missing Testing Strategy (CRITICAL)
**Problem**: No validation approach for generated code correctness
- **Missing**: Unit testing approach for AST transformations
- **Missing**: Integration testing strategy for generated clients
- **Missing**: Validation approach for code correctness
- **Impact**: Cannot verify implementation correctness
- **Resolution Required**: Define comprehensive testing strategy

### HIGH PRIORITY GAPS

#### 5. Performance and Scale Considerations (HIGH)
**Problem**: No guidance for large-scale usage
- **Missing**: Memory usage patterns for large proto batches
- **Missing**: Parallel processing coordination strategy
- **Missing**: Incremental generation capabilities
- **Impact**: May not scale for production codebases
- **Resolution Required**: Define performance requirements and strategies

### REQUIRED ACTIONS BEFORE IMPLEMENTATION

1. **Resolve Interface Conflict** 
   - **Decision**: Adopt file-centric `GeneratorOptions` model
   - **Action**: Update `/libs/grpc-client-generator/src/index.ts` interface
   - **Validation**: Ensure backward compatibility or migration strategy

2. **Define Complete Dependency Chain**
   - **Action**: Add dependencies to `package.json`:
     - `ts-proto: ~1.x.x` (specify exact version)
     - `ts-morph: ~20.x.x` (specify exact version)  
     - `grpc-tools` or equivalent for protoc binary
   - **Validation**: Test dependency compatibility matrix

3. **Add Comprehensive Error Handling**
   - **Action**: Add "Error Handling" section to specification
   - **Requirements**: 
     - Transactional generation (all-or-nothing)
     - Clear error messages with actionable guidance
     - Temporary file strategy to prevent partial corruption
   - **Validation**: Define error recovery test scenarios

4. **Define Testing Strategy**
   - **Action**: Add "Testing Strategy" section to specification
   - **Requirements**:
     - Unit tests for AST transformation functions
     - Integration tests with mock gRPC servers
     - Snapshot tests for generated code structure
   - **Validation**: Test coverage requirements (>90%)

5. **Address Performance Considerations**
   - **Action**: Add "Performance Requirements" section
   - **Requirements**:
     - Memory usage limits for batch processing
     - Parallel processing coordination
     - Incremental generation capabilities
   - **Validation**: Performance benchmarks and thresholds

### RISK ASSESSMENT

**Implementation Risk**: HIGH
- Multiple blocking dependencies on external design decisions
- Significant rework required for existing placeholder code
- No validation strategy to ensure correctness
- Potential for production stability issues without proper error handling

**Recommendation**: **DO NOT PROCEED** with implementation until all blocking issues are resolved and the specification is updated with the required sections.

### NEXT STEPS

1. Update specification with missing sections
2. Resolve interface design conflict
3. Update package.json with required dependencies
4. Create comprehensive test strategy
5. Define error handling and performance requirements
6. Re-validate specification completeness before implementation begins