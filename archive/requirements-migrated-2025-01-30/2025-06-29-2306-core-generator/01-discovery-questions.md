# Discovery Questions

## Q1: Should the generator create client-side gRPC stubs (for consuming gRPC services) rather than server-side implementations?
**Default if unknown:** Yes (the name "grpc-client-generator" suggests client-side code generation)

**Context:** The existing APIs have server implementations, but a client generator would create TypeScript code for other services to call these gRPC APIs.

## Q2: Should the generator support the same ts-proto pipeline that's currently used in the APIs?
**Default if unknown:** Yes (maintains consistency with existing codebase patterns)

**Context:** The APIs use `protoc` with `ts-proto` plugin. The generator could wrap this workflow with additional features.

## Q3: Should the generated clients include built-in features like header forwarding, logging, and error handling?
**Default if unknown:** Yes (package.json description explicitly mentions these features)

**Context:** The package description states "built-in features such as header forwarding, logging and error handling".

## Q4: Should the generator support batch processing of multiple proto files in a single operation?
**Default if unknown:** Yes (the GeneratorOptions interface suggests multiple services support)

**Context:** The current interface accepts `services: ServiceConfig[]` indicating multi-service support.

## Q5: Should the generated output be standalone TypeScript files that can be published as npm packages?
**Default if unknown:** Yes (enables sharing generated clients across multiple consuming applications)

**Context:** Client libraries are typically shared across multiple applications that need to call the same gRPC services.