# Expert Requirements Questions

**Phase:** Expert Detail  
**Total Questions:** 5

## Q1: Should retry attempts be limited to protoc/ts-proto command failures only?
**Default if unknown:** Yes (limit scope to external process failures, not AST processing)

**Rationale:** Retries should focus on transient external failures (protoc binary issues, file system locks) rather than code generation logic failures which indicate bugs requiring fixes.

## Q2: Should incremental compilation track proto file dependencies (imports) for selective regeneration?
**Default if unknown:** Yes (import changes should trigger downstream regeneration)

**Rationale:** Proto files can import other proto files. When a base proto changes, all importing files need regeneration to maintain consistency, similar to TypeScript's dependency tracking.

## Q3: Should the generator pin ts-proto to exact version ~2.7.5 to prevent AST parsing breaks?
**Default if unknown:** Yes (AST structure changes between versions can break parsing)

**Rationale:** The generator's AST filtering logic depends on specific ts-proto output structure. Minor version updates could change node structures and break client extraction logic.

## Q4: Should integration tests mock gRPC services or require real service implementations?
**Default if unknown:** Mock (easier setup, more predictable testing environment)

**Rationale:** Mock services provide controlled testing environment, faster execution, and don't require standing up actual gRPC servers. Real services can be tested separately in end-to-end validation.

## Q5: Should the generator support batch size limits to prevent memory issues with large proto sets?
**Default if unknown:** Yes (prevent out-of-memory failures on large codebases)

**Rationale:** Processing hundreds of proto files simultaneously could exhaust memory. Batch processing with configurable limits ensures reliability across different system configurations.