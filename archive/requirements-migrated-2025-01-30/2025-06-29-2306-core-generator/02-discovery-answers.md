# Discovery Answers

## Q1: Should the generator create client-side gRPC stubs (for consuming gRPC services) rather than server-side implementations?
**Answer:** Yes

## Q2: Should the generator support the same ts-proto pipeline that's currently used in the APIs?
**Answer:** Yes

## Q3: Should the generated clients include built-in features like header forwarding, logging, and error handling?
**Answer:** Yes

## Q4: Should the generator support batch processing of multiple proto files in a single operation?
**Answer:** Yes

## Q5: Should the generated output be standalone TypeScript files that can be published as npm packages?
**Answer:** Not necessary, they can be created build-time client-side.

## Summary
The core generator should create client-side gRPC TypeScript code using ts-proto pipeline, with built-in features for header forwarding, logging, and error handling. It should support batch processing multiple proto files and generate build-time client files rather than standalone npm packages.