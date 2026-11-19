import { vi } from 'vitest'

// The provider only uses this base class to identify class-based handlers.
// Tests exercise its real routing with ordinary fetch handlers.
export class WorkerEntrypoint {}

export const waitUntil = vi.fn<(promise: Promise<unknown>) => void>()
