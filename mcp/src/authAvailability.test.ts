import { afterEach, describe, expect, it, vi } from 'vitest'
import { OAuthProvider } from '@cloudflare/workers-oauth-provider'
import { handlePublicRequest, resolveExternalPat } from './oauth'
import { verifySupabaseUserWith } from './supabaseUser'
import { hashSecret } from './token'
import type { TokenSecret } from './domain'

const tokenId = '11111111-1111-4111-8111-111111111111'
const env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'test-anon',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service',
  WEB_ORIGINS: 'https://lmr.sillyapps.co',
  OAUTH_KV: { get: async () => null },
} as unknown as Env
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json' },
})
afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers() })

const routes = [
  ['GET', '/consent'], ['POST', '/consent/deny'], ['POST', '/bind'],
  ['GET', '/grants'], ['POST', '/grants/revoke'], ['POST', '/account/grants/cleanup'],
]

describe('browser authentication availability', () => {
  it.each(routes)('%s %s preserves verification outages and rejected credentials', async (method, path) => {
    for (const status of [503, 500, 429, 401, 403]) {
      const response = await handlePublicRequest(new Request(`https://lmr-mcp.edmundlim.systems${path}`, {
        method, headers: { Authorization: 'Bearer test-session', Origin: env.WEB_ORIGINS },
      }), env, {
        verifyUser: verifySupabaseUserWith(async () => json(status, { message: 'test failure' })),
        accountExists: vi.fn(),
      })
      expect(response.status).toBe(status === 401 || status === 403 ? 401 : 503)
      expect(await response.json()).toEqual({ error: status === 401 || status === 403 ? 'unauthorized' : 'account_lookup_unavailable' })
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(env.WEB_ORIGINS)
      expect(response.headers.get('Cache-Control')).toBe('no-store')
    }
  })

  it('returns a controlled response when the network fails', async () => {
    // Supabase logs fetch exceptions; suppress the synthetic failure in this test.
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      const response = await handlePublicRequest(new Request('https://lmr-mcp.edmundlim.systems/consent', {
        headers: { Authorization: 'Bearer test-session' },
      }), env, {
        verifyUser: verifySupabaseUserWith(async () => { throw new TypeError('test network failure') }),
        accountExists: vi.fn(),
      })
      expect(response.status).toBe(503)
      expect(await response.json()).toEqual({ error: 'account_lookup_unavailable' })
    } finally { log.mockRestore() }
  })
})

describe('personal token authentication through the OAuth provider', () => {
  const accepted = vi.fn(async () => new Response('accepted'))
  const background: Promise<unknown>[] = []
  const provider = new OAuthProvider<Env>({
    apiRoute: '/mcp', apiHandler: { fetch: accepted },
    defaultHandler: { fetch: async () => new Response(null, { status: 404 }) },
    authorizeEndpoint: '/authorize', tokenEndpoint: '/token',
    resolveExternalToken: (input) => resolveExternalPat(input, (promise) => { background.push(promise) }),
  })
  const request = () => provider.fetch(new Request('https://lmr-mcp.edmundlim.systems/mcp', {
    headers: { Authorization: `Bearer lmr_${tokenId}_test-secret` },
  }), env, { waitUntil: vi.fn() } as unknown as ExecutionContext)

  afterEach(async () => {
    await Promise.all(background.splice(0))
  })

  it.each([204, 503])('authenticates before bookkeeping completes with status %s', async (status) => {
    const token_hash = await hashSecret('test-secret' as TokenSecret)
    let finish!: (response: Response) => void
    const pendingWrite = new Promise<Response>((resolve) => { finish = resolve })
    const fetch = vi.fn(async (_input: unknown, init?: RequestInit) => init?.method === 'PATCH'
      ? pendingWrite
      : json(200, { id: tokenId, user_id: tokenId, name: 'Test', token_hash, revoked_at: null }))
    vi.stubGlobal('fetch', fetch)
    let response: Response | undefined
    const pending = request().then((result) => { response = result })
    try {
      await vi.waitFor(() => expect(response?.status).toBe(200))
      expect(background).toHaveLength(1)
      expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(true)
    } finally {
      finish(status === 204 ? new Response(null, { status }) : json(status, { message: 'test storage failure' }))
      await pending
      await Promise.all(background)
    }
  })

  it.each([503, 500, 429, 'network'])('returns 503 for lookup failure %s, then permits retry', async (failure) => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })
    accepted.mockClear()
    vi.stubGlobal('fetch', async () => {
      if (failure === 'network') throw new TypeError('test network failure')
      return json(failure as number, { message: 'test storage failure' })
    })
    const pending = request()
    await vi.runAllTimersAsync()
    const response = await pending
    expect(response.status).toBe(503)
    expect(await response.json()).toMatchObject({ error: 'temporarily_unavailable' })
    expect(accepted).not.toHaveBeenCalled()

    const token_hash = await hashSecret('test-secret' as TokenSecret)
    vi.stubGlobal('fetch', async (_input: unknown, init?: RequestInit) => init?.method === 'PATCH'
      ? new Response(null, { status: 204 })
      : json(200, { id: tokenId, user_id: tokenId, name: 'Test', token_hash, revoked_at: null }))
    expect((await request()).status).toBe(200)
    expect(accepted).toHaveBeenCalledOnce()
  })

  it.each(['missing', 'revoked', 'wrong-secret'])('still rejects a %s token', async (kind) => {
    vi.stubGlobal('fetch', async () => json(200, kind === 'missing' ? null : {
      id: tokenId, user_id: tokenId, name: 'Test', token_hash: '00'.repeat(32),
      revoked_at: kind === 'revoked' ? '2026-01-01T00:00:00Z' : null,
    }))
    expect((await request()).status).toBe(401)
  })
})
