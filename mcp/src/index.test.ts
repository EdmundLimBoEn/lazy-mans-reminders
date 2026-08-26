import { describe, expect, it } from 'vitest'
import { handlePublicRequest } from './oauth'

function memoryKv(): KVNamespace {
  const store = new Map<string, string>()
  return {
    get: async (key: string, type?: string) => {
      const value = store.get(key)
      if (value === undefined) return null
      if (type === 'json') return JSON.parse(value)
      return value
    },
    put: async (key: string, value: string) => {
      store.set(key, value)
    },
    delete: async (key: string) => {
      store.delete(key)
    },
    list: async () => ({ keys: [], list_complete: true, cursor: '', cacheStatus: null }),
    getWithMetadata: async () => ({ value: null, metadata: null, cacheStatus: null }),
  } as unknown as KVNamespace
}

const env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
  SUPABASE_ANON_KEY: 'test-anon',
  WEB_ORIGINS: 'https://lmr.edmundlim.systems,http://localhost:5173',
  OAUTH_KV: memoryKv(),
} as Env

describe('mcp worker routes', () => {
  it('serves an unauthenticated server card', async () => {
    const response = await handlePublicRequest(
      new Request('https://lmr-mcp.edmundlim.systems/'),
      env,
    )
    expect(response.status).toBe(200)
    const body = await response.json() as { url: string; auth: { type: string }; tools: string[] }
    expect(body.url).toBe('/mcp')
    expect(body.auth.type).toBe('oauth')
    expect(body.tools).toContain('list_reminders')
    expect(body.tools).toContain('whoami')
  })

  it('rejects bind without a signed-in session', async () => {
    const response = await handlePublicRequest(
      new Request('https://lmr-mcp.edmundlim.systems/bind', {
        method: 'POST',
        headers: {
          Origin: 'https://lmr.edmundlim.systems',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ state: '550e8400-e29b-41d4-a716-446655440000' }),
      }),
      env,
    )
    expect(response.status).toBe(401)
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://lmr.edmundlim.systems')
  })
})
