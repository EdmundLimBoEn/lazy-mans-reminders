import { getOAuthApi } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it, vi } from 'vitest'
import { memoryObjects } from '../test/memoryObjects'
import { AuthorizationState } from './authorizationState'
import { MCP_HOST, MCP_RESOURCE } from './constants'
import { GrantState } from './grantState'
import { handleWorkerFetch } from './index'

// Exercise the real provider's validation, issuance and refresh; stub only MCP transport.
vi.mock('agents/mcp/server', () => ({
  createMcpHandler: () => ({ fetch: async () => Response.json({ accepted: true }) }),
}))

const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const REDIRECT = 'https://client.example/callback'
const OTHER_REDIRECT = 'https://client.example/other-callback'
const VERIFIER = 'a'.repeat(43)

async function setup(format: 'form' | 'json' = 'form') {
  const kv = new Map<string, string>()
  const states = new Map<string, DurableObjectState>()
  const objects = new Map<string, AuthorizationState>()
  const accountExists = vi.fn(async () => true)
  const env = {
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service',
    WEB_ORIGINS: 'https://np.sillyapps.co',
    AUTH_RATE_LIMIT: { limit: async () => ({ success: true }) },
    MCP_RATE_LIMIT: { limit: async () => ({ success: true }) },
    OAUTH_KV: {
      get: vi.fn(async (key: string, options?: string | { type: string }) => {
        const value = kv.get(key)
        const type = typeof options === 'string' ? options : options?.type
        return value === undefined ? null : type === 'json' ? JSON.parse(value) : value
      }),
      put: vi.fn(async (key: string, value: string) => { kv.set(key, value) }),
      delete: async (key: string) => { kv.delete(key) },
    },
    AUTHORIZATION_STATE: {
      idFromName: (name: string) => name,
      get: (id: string) => ({
        fetch: (input: string, init?: RequestInit) => {
          if (!states.has(id)) {
            const entries = new Map<string, unknown>()
            let queue = Promise.resolve()
            const storage = {
              get: async (key: string) => entries.get(key),
              put: async (key: string, value: unknown) => { entries.set(key, value) },
              delete: async (key: string) => entries.delete(key),
              // Serialize transactions as Durable Object storage does, not whole requests.
              transaction: <T>(fn: (store: unknown) => Promise<T>): Promise<T> => {
                const result = queue.then(() => fn(storage))
                queue = result.then(() => {}, () => {})
                return result
              },
            }
            states.set(id, { storage } as unknown as DurableObjectState)
          }
          if (!objects.has(id)) objects.set(id, new AuthorizationState(states.get(id)!))
          return objects.get(id)!.fetch(new Request(input, init))
        },
      }),
    },
  } as unknown as Env
  env.GRANT_STATE = memoryObjects((state) => new GrantState(state, env))
  const oauth = getOAuthApi<Env>({
    apiRoute: '/mcp',
    apiHandler: { fetch: async () => new Response() },
    defaultHandler: { fetch: async () => new Response() },
    authorizeEndpoint: '/authorize',
    tokenEndpoint: '/token',
    scopesSupported: ['board'],
    resourceMetadata: { resource: MCP_RESOURCE },
  }, env)
  const client = await oauth.createClient({
    redirectUris: [REDIRECT, OTHER_REDIRECT], tokenEndpointAuthMethod: 'none',
    grantTypes: ['authorization_code', 'refresh_token'], responseTypes: ['code'],
  })
  const challenge = Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(VERIFIER))).toString('base64url')
  const { redirectTo } = await oauth.completeAuthorization({
    request: {
      clientId: client.clientId, redirectUri: REDIRECT, responseType: 'code', scope: ['board'], state: '',
      codeChallenge: challenge, codeChallengeMethod: 'S256', resource: MCP_RESOURCE,
    },
    userId: USER, scope: ['board'], metadata: {}, props: { userId: USER, tokenId: 'oauth', agentName: 'Test' },
    revokeExistingGrants: false,
  })
  const code = new URL(redirectTo).searchParams.get('code')!
  const request = (path: string, init?: RequestInit) => handleWorkerFetch(
    new Request(`https://${MCP_HOST}${path}`, init), env,
    { waitUntil: vi.fn() } as unknown as ExecutionContext,
    { verifyUser: async () => null, accountExists },
  )
  const token = (body: Record<string, string>) => request(format === 'json' ? '/token/' : '/token', {
    method: 'POST', headers: { 'Content-Type': format === 'json' ? 'application/json' : 'application/x-www-form-urlencoded' },
    body: format === 'json' ? JSON.stringify(body) : new URLSearchParams(body).toString(),
  })
  const exchange = (overrides: Record<string, string> = {}) => token({
    grant_type: 'authorization_code', client_id: client.clientId, code, redirect_uri: REDIRECT,
    code_verifier: VERIFIER, ...overrides,
  })
  vi.mocked(env.OAUTH_KV.put).mockClear()
  return { env, kv, objects, accountExists, oauth, client, code, exchange, token, request }
}

describe('authorization code redemption', () => {
  it.each(['form', 'json'] as const)('rejects a different registered redirect URI in %s without consuming the code', async (format) => {
    const { exchange, env, accountExists } = await setup(format)
    const rejected = await exchange({ redirect_uri: OTHER_REDIRECT })
    expect(rejected.status).toBe(400)
    expect(await rejected.json()).toMatchObject({ error: 'invalid_grant' })
    expect(rejected.headers.get('Cache-Control')).toBe('no-store')
    expect(rejected.headers.get('Access-Control-Allow-Origin')).toBe('*')
    expect(env.OAUTH_KV.put).not.toHaveBeenCalled()
    expect(accountExists).not.toHaveBeenCalled()

    const accepted = await exchange()
    expect(accepted.status).toBe(200)
    expect(await accepted.json()).toMatchObject({
      access_token: expect.any(String), refresh_token: expect.any(String),
    })
  })

  it('redeems a code with its original redirect URI', async () => {
    const { exchange } = await setup()
    const response = await exchange()
    expect(response.status).toBe(200)
    expect(await response.json()).toMatchObject({
      access_token: expect.any(String), refresh_token: expect.any(String),
    })
  })

  it.each(['missing', 'empty'])('rejects a %s redirect URI even with valid PKCE', async (redirect) => {
    const { exchange, token, client, code, env } = await setup()
    const response = await token({
      grant_type: 'authorization_code', client_id: client.clientId, code, code_verifier: VERIFIER,
      ...(redirect === 'empty' ? { redirect_uri: '' } : {}),
    })
    expect(response.status).toBe(400)
    expect(await response.json()).toMatchObject({ error: 'invalid_grant' })
    expect(env.OAUTH_KV.put).not.toHaveBeenCalled()
    expect((await exchange()).status).toBe(200)
  })

  it('fails closed if the stored grant has no original redirect URI', async () => {
    const { exchange, kv, env } = await setup()
    const [key, value] = [...kv.entries()].find(([key]) => key.startsWith('grant:'))!
    const grant = JSON.parse(value)
    delete grant.redirectUri
    kv.set(key, JSON.stringify(grant))
    const response = await exchange()
    expect(response.status).toBe(400)
    expect(await response.json()).toMatchObject({ error: 'invalid_grant' })
    expect(env.OAUTH_KV.put).not.toHaveBeenCalled()
  })

  it('issues only one token response when two validated exchanges overlap', async () => {
    const { exchange, accountExists, env, token, client, request } = await setup()
    let release!: () => void
    const bothValidated = new Promise<void>((resolve) => { release = resolve })
    let arrivals = 0
    accountExists.mockImplementation(async () => {
      if (++arrivals === 2) release()
      await bothValidated
      return true
    })
    const responses = await Promise.all([exchange(), exchange()])
    expect(responses.map((response) => response.status).sort()).toEqual([200, 400])
    expect(await responses.find((response) => response.status === 400)!.json()).toMatchObject({ error: 'invalid_grant' })
    expect(vi.mocked(env.OAUTH_KV.put).mock.calls.filter(([key]) => key.startsWith('token:'))).toHaveLength(1)
    const tokens = await responses.find((response) => response.status === 200)!.json() as { access_token: string; refresh_token: string }
    expect((await request('/mcp', { headers: { Authorization: `Bearer ${tokens.access_token}` } })).status).toBe(200)
    expect((await token({ grant_type: 'refresh_token', client_id: client.clientId, refresh_token: tokens.refresh_token })).status).toBe(200)
  })

  it('retries a rejected first grant write after the claiming object restarts', async () => {
    const { exchange, env, kv, objects } = await setup()
    vi.mocked(env.OAUTH_KV.put).mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    const rejected = await exchange()
    expect(rejected.status).toBe(429)
    expect(rejected.headers.get('Retry-After')).toBe('30')
    expect(await rejected.json()).toMatchObject({ error: 'temporarily_unavailable' })
    expect([...kv.keys()].filter((key) => key.startsWith('token:'))).toHaveLength(0)
    objects.clear()
    expect((await exchange()).status).toBe(200)
    expect((await exchange()).status).toBe(400)
    expect([...kv.keys()].filter((key) => key.startsWith('token:'))).toHaveLength(1)
  })

  it('does not let a delayed release reopen a later successful claim', async () => {
    const { exchange, env } = await setup()
    const get = env.AUTHORIZATION_STATE.get.bind(env.AUTHORIZATION_STATE)
    let releaseRequest: Request | undefined
    vi.spyOn(env.AUTHORIZATION_STATE, 'get').mockImplementation((id) => {
      const stub = get(id)
      return { fetch: async (input: string, init?: RequestInit) => {
        if (input.endsWith('/release')) releaseRequest = new Request(input, init)
        return stub.fetch(input, init)
      } } as DurableObjectStub
    })
    vi.mocked(env.OAUTH_KV.put).mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    expect((await exchange()).status).toBe(429)
    expect(releaseRequest).toBeDefined()
    expect((await exchange()).status).toBe(200)
    const attempt = await releaseRequest!.json() as { attempt: string }
    // Retry a delayed release against the same object after successful issuance.
    const id = vi.mocked(env.AUTHORIZATION_STATE.get).mock.calls[0][0]
    await get(id).fetch('https://authorization-state/release', {
      method: 'POST', body: JSON.stringify(attempt),
    })
    const claim = await get(id).fetch('https://authorization-state/redeem', {
      method: 'POST', body: JSON.stringify({ attempt: 'replay' }),
    })
    expect(await claim.json()).toEqual({ consumed: false })
  })

  it.each(['uncertain', 'token'])('keeps the code consumed after a %s write failure', async (failure) => {
    const { exchange, env, kv, objects } = await setup()
    const [grantKey, unusedGrant] = [...kv.entries()].find(([key]) => key.startsWith('grant:'))!
    vi.mocked(env.OAUTH_KV.put).mockImplementationOnce(async (key, value) => {
      if (failure === 'uncertain') throw new Error('Connection lost')
      kv.set(key, value as string)
    })
    if (failure === 'token') {
      vi.mocked(env.OAUTH_KV.put).mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
      expect((await exchange()).status).toBe(429)
    } else {
      await expect(exchange()).rejects.toThrow('Connection lost')
    }
    objects.clear()
    // Model an eventually consistent read of the original unused grant.
    vi.mocked(env.OAUTH_KV.get).mockImplementation((async (key: string, options?: string | { type: string }) => {
      const value = key === grantKey ? unusedGrant : kv.get(key)
      const type = typeof options === 'string' ? options : options?.type
      return value === undefined ? null : type === 'json' ? JSON.parse(value) : value
    }) as typeof env.OAUTH_KV.get)
    expect((await exchange()).status).toBe(400)
  })

  it('rejects a stale unused-code read after the claiming object restarts', async () => {
    const { exchange, env, kv, objects } = await setup()
    const [grantKey, unusedGrant] = [...kv.entries()].find(([key]) => key.startsWith('grant:'))!
    expect((await exchange()).status).toBe(200)
    objects.clear()
    vi.mocked(env.OAUTH_KV.get).mockImplementation((async (key: string, options?: string | { type: string }) => {
      const value = key === grantKey ? unusedGrant : kv.get(key)
      const type = typeof options === 'string' ? options : options?.type
      return value === undefined ? null : type === 'json' ? JSON.parse(value) : value
    }) as typeof env.OAUTH_KV.get)
    const replay = await exchange()
    expect(replay.status).toBe(400)
    expect(await replay.json()).toMatchObject({ error: 'invalid_grant' })
    expect(vi.mocked(env.OAUTH_KV.put).mock.calls.filter(([key]) => key.startsWith('token:'))).toHaveLength(1)
  })

  it.each(['pkce', 'client', 'scope', 'resource', 'account'])('does not consume the code when %s validation fails', async (failure) => {
    const { exchange, accountExists, oauth } = await setup()
    const overrides: Record<string, string> = {}
    if (failure === 'pkce') overrides.code_verifier = 'b'.repeat(43)
    if (failure === 'client') {
      const other = await oauth.createClient({ redirectUris: [REDIRECT], tokenEndpointAuthMethod: 'none' })
      overrides.client_id = other.clientId
    }
    if (failure === 'scope') overrides.scope = 'other'
    if (failure === 'resource') overrides.resource = 'https://other.example/mcp'
    if (failure === 'account') accountExists.mockRejectedValueOnce(new Error('Unavailable'))
    expect((await exchange(overrides)).status).toBe(failure === 'account' ? 503 : 400)
    expect((await exchange()).status).toBe(200)
  })

  it('does not issue credentials if the atomic claim is unavailable', async () => {
    const { exchange, env } = await setup()
    vi.spyOn(env.AUTHORIZATION_STATE, 'get').mockImplementationOnce(() => { throw new Error('Unavailable') })
    expect((await exchange()).status).toBe(503)
    expect(env.OAUTH_KV.put).not.toHaveBeenCalled()
    expect((await exchange()).status).toBe(200)
  })
})
