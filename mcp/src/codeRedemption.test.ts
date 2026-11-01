import { getOAuthApi } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it, vi } from 'vitest'
import { AuthorizationState } from './authorizationState'
import { GrantState } from './grantState'
import { memoryObjects } from '../test/memoryObjects'
import { MCP_HOST, MCP_RESOURCE } from './constants'
import { handleWorkerFetch } from './index'

// Exercise the real provider's validation, issuance and refresh; stub only MCP transport.
vi.mock('agents/mcp/server', () => ({
  createMcpHandler: () => ({ fetch: async () => Response.json({ accepted: true }) }),
}))

const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const REDIRECT = 'https://client.example/callback'
const VERIFIER = 'a'.repeat(43)

async function setup() {
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
    redirectUris: [REDIRECT], tokenEndpointAuthMethod: 'none',
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
  const token = (body: Record<string, string>) => request('/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(body).toString(),
  })
  const exchange = (overrides: Record<string, string> = {}) => token({
    grant_type: 'authorization_code', client_id: client.clientId, code, redirect_uri: REDIRECT,
    code_verifier: VERIFIER, ...overrides,
  })
  vi.mocked(env.OAUTH_KV.put).mockClear()
  return { env, kv, objects, accountExists, oauth, client, exchange, token, request }
}

describe('authorization code redemption', () => {
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
