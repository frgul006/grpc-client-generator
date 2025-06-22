import { type ServerUnaryCall, type sendUnaryData } from '@grpc/grpc-js'
import { vi } from 'vitest'

/**
 * Creates a type-safe mock ServerUnaryCall object for testing gRPC service methods.
 * Uses TypeScript's Pick utility to include only the 'request' property.
 */
export function createMockServerUnaryCall<TRequest, TResponse>(
  request: TRequest,
): Pick<ServerUnaryCall<TRequest, TResponse>, 'request'> {
  return { request }
}

/**
 * Creates a properly typed mock callback for gRPC service methods.
 */
export function createMockCallback<TResponse>(): vi.MockedFunction<
  sendUnaryData<TResponse>
> {
  return vi.fn()
}

// Type aliases for convenience
export type MockServerUnaryCall<TRequest, TResponse> = Pick<
  ServerUnaryCall<TRequest, TResponse>,
  'request'
>
export type MockSendUnaryData<TResponse> = vi.MockedFunction<
  sendUnaryData<TResponse>
>
