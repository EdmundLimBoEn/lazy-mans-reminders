import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { enforceRateLimit, rateLimitBucket } from './rateLimit'

describe('rateLimitBucket', () => {
  it.each(['/mcp', '/mcp/', '/mcp/anything', '/mcp/nested/path/'])('covers the MCP prefix %s', (path) => {
    expect(rateLimitBucket(path)).toBe('mcp')
  })

  it.each(['/mcpx', '/mcpx/anything'])('excludes %s', (path) => {
    expect(rateLimitBucket(path)).toBeNull()
  })

  it('covers registration, authorize, token, bind, consent, grants, and mcp', () => {
    expect(rateLimitBucket('/register')).toBe('auth')
    expect(rateLimitBucket('/authorize/')).toBe('auth')
    expect(rateLimitBucket('/token')).toBe('auth')
    expect(rateLimitBucket('/bind')).toBe('auth')
    expect(rateLimitBucket('/consent')).toBe('auth')
    expect(rateLimitBucket('/grants/revoke')).toBe('auth')
    expect(rateLimitBucket('/mcp')).toBe('mcp')
    expect(rateLimitBucket('/')).toBeNull()
  })
})

describe('enforceRateLimit', () => {
  it.each(['/mcp/anything', '/mcp/nested/path/'])('limits bogus tokens on %s', async (path) => {
    const keys: string[] = []
    const response = await enforceRateLimit(
      new Request(`https://lmr-mcp.edmundlim.systems${path}`, {
        headers: { Authorization: 'Bearer bogus', 'CF-Connecting-IP': '192.0.2.1' },
      }),
      { MCP_RATE_LIMIT: { limit: async ({ key }: { key: string }) => {
        keys.push(key)
        return { success: false }
      } } } as unknown as Env,
    )
    expect(response?.status).toBe(429)
    expect(response?.headers.get('Retry-After')).toBe('60')
    expect(keys).toEqual(['mcp:192.0.2.1'])
  })

  it('returns 429 when the limiter refuses and 503 when the binding is missing', async () => {
    const limited = await enforceRateLimit(
      new Request('https://lmr-mcp.edmundlim.systems/register', { method: 'POST' }),
      { AUTH_RATE_LIMIT: { limit: async () => ({ success: false }) } } as unknown as Env,
    )
    expect(limited?.status).toBe(429)

    const missing = await enforceRateLimit(
      new Request('https://lmr-mcp.edmundlim.systems/mcp', { method: 'POST' }),
      {} as Env,
    )
    expect(missing?.status).toBe(503)
  })
})

describe('worker config', () => {
  it('turns off workers.dev and does not allow a loopback production origin', () => {
    const source = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../wrangler.jsonc'), 'utf8')
    expect(source).toContain('"workers_dev": false')
    expect(source).toContain('"preview_urls": false')
    const origins = source.match(/"WEB_ORIGINS":\s*"([^"]+)"/)?.[1]
    expect(origins).toBe('https://lmr.sillyapps.co,https://lmr.edmundlim.systems,https://lazy-mans-reminders.pages.dev')
    // /authorize sends the browser to the FIRST origin's /connect page, so it must be the canonical domain.
    expect(origins?.split(',')[0]).toBe('https://lmr.sillyapps.co')
  })
})
