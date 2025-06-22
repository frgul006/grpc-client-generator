// Test setup for product-service
import { vi } from 'vitest'

// Mock the gRPC library
vi.mock('@grpc/grpc-js', () => ({
  Server: vi.fn().mockImplementation(() => ({
    addService: vi.fn(),
    bindAsync: vi.fn(),
    start: vi.fn(),
  })),
  ServerCredentials: {
    createInsecure: vi.fn(() => 'mock-insecure-credentials'),
  },
  status: {
    OK: 0,
    CANCELLED: 1,
    UNKNOWN: 2,
    INVALID_ARGUMENT: 3,
    DEADLINE_EXCEEDED: 4,
    NOT_FOUND: 5,
    ALREADY_EXISTS: 6,
    PERMISSION_DENIED: 7,
    RESOURCE_EXHAUSTED: 8,
    FAILED_PRECONDITION: 9,
    ABORTED: 10,
    OUT_OF_RANGE: 11,
    UNIMPLEMENTED: 12,
    INTERNAL: 13,
    UNAVAILABLE: 14,
    DATA_LOSS: 15,
    UNAUTHENTICATED: 16,
  },
}))

// Mock console methods for cleaner test output
const originalConsole = { ...console }

export function mockConsole(): void {
  console.log = vi.fn()
  console.error = vi.fn()
  console.warn = vi.fn()
  console.info = vi.fn()
}

export function restoreConsole(): void {
  Object.assign(console, originalConsole)
}
