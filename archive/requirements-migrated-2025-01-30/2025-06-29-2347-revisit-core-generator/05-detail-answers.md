# Expert Detail Answers

**Phase:** Expert Detail Complete  
**Answered:** 5/5

## Q1: Should retry attempts be limited to protoc/ts-proto command failures only?
**Answer:** Yes  
**Rationale:** Limit scope to external process failures, not AST processing

## Q2: Should incremental compilation track proto file dependencies (imports) for selective regeneration?
**Answer:** Yes  
**Rationale:** Import changes should trigger downstream regeneration

## Q3: Should the generator pin ts-proto to exact version ~2.7.5 to prevent AST parsing breaks?
**Answer:** Should pin to whatever library is using  
**Rationale:** Version compatibility should match consuming library requirements

## Q4: Should integration tests mock gRPC services or require real service implementations?
**Answer:** Yes, e2e tests should cover real service but not integration  
**Rationale:** Mock for integration tests, real services for e2e validation

## Q5: Should the generator support batch size limits to prevent memory issues with large proto sets?
**Answer:** No  
**Rationale:** Memory management not required as constraint for this implementation