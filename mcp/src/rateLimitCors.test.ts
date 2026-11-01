import { describe, expect, it, vi } from 'vitest'
import { handleWorkerFetch } from './index'

vi.mock('agents/mcp/server', () => ({ createMcpHandler: vi.fn() }))

const externalOrigin = 'https://client.example'
const webOrigin = 'https://np.sillyapps.co'
const ctx = { waitUntil: vi.fn() } as unknown as ExecutionContext

function request(path: string, origin = externalOrigin, method = 'POST') {
  return new Request(`https://np-mcp.sillyapps.co${path}`, {
    method, headers: { Origin: origin },
  })
}

function environment(outcome: 'allowed' | 'limited' | 'missing' | 'error'): Env {
  const limiter = outcome === 'missing' ? undefined : {
    limit: async () => {
      if (outcome === 'error') throw new Error('test limiter failure')
      return { success: outcome === 'allowed' }
    },
  }
  return {
    WEB_ORIGINS: webOrigin, AUTH_RATE_LIMIT: limiter, MCP_RATE_LIMIT: limiter,
    // These unauthenticated requests never read storage, but the worker wraps
    // the KV binding before passing requests to the real OAuth provider.
    OAUTH_KV: {},
  } as unknown as Env
}

const publicPaths = ['/mcp', '/mcp/', '/mcp/nested', '/mcpx', '/token', '/token/', '/register', '/register/']

describe('worker rate-limit CORS', () => {
  it.each(publicPaths)('keeps external clients able to read 429 and Retry-After on %s', async (path) => {
    // Exercise the real provider's ordinary CORS policy as well as the early return.
    const ordinary = await handleWorkerFetch(request(path), environment('allowed'), ctx)
    expect(ordinary.headers.get('Access-Control-Allow-Origin')).toBe(externalOrigin)
    const limited = await handleWorkerFetch(request(path), environment('limited'), ctx)
    expect(limited.status).toBe(429)
    expect(limited.headers.get('Access-Control-Allow-Origin')).toBe(externalOrigin)
    expect(limited.headers.get('Access-Control-Expose-Headers')?.toLowerCase().split(/,\s*/)).toContain('retry-after')
    expect(limited.headers.get('Retry-After')).toBe('60')
    expect(limited.headers.get('Cache-Control')).toBe('no-store')
    expect(await limited.json()).toEqual({ error: 'rate_limited' })
  })

  it.each(['missing', 'error'] as const)('preserves public CORS when the limiter is %s', async (outcome) => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      for (const path of publicPaths) {
        const response = await handleWorkerFetch(request(path), environment(outcome), ctx)
        expect(response.status).toBe(503)
        expect(response.headers.get('Access-Control-Allow-Origin')).toBe(externalOrigin)
      }
    } finally {
      log.mockRestore()
    }
  })

  it.each(['/authorize', '/bind/', '/consent', '/consent/deny', '/grants', '/grants/revoke', '/account/grants/cleanup'])('retains the web origin allowlist on %s', async (path) => {
    for (const origin of [externalOrigin, webOrigin]) {
      const response = await handleWorkerFetch(request(path, origin), environment('limited'), ctx)
      expect(response.status).toBe(429)
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(origin === webOrigin ? webOrigin : null)
    }
  })

  it.each(publicPaths)('allows preflight while the limiter refuses on %s', async (path) => {
    const response = await handleWorkerFetch(request(path, externalOrigin, 'OPTIONS'), environment('limited'), ctx)
    expect(response.status).toBe(204)
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe(externalOrigin)
  })
})
