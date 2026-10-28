import type { AuthRequest, ClientInfo, GrantSummary, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it, vi } from 'vitest'
import { AuthorizationState } from './authorizationState'
import { PENDING_AUTH_TTL_SECONDS } from './constants'
import { handlePublicRequest } from './oauth'
import type { IdentityDeps } from './supabaseUser'

const USER_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const USER_B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
const STATE_GROK = '11111111-1111-4111-8111-111111111111'
const STATE_CURSOR = '22222222-2222-4222-8222-222222222222'
const STATE_HTTP = '33333333-3333-4333-8333-333333333333'
const STATE_PLAIN = '44444444-4444-4444-8444-444444444444'

function memoryKv() {
  const store = new Map<string, string>()
  return {
    get: async (key: string, type?: string) => {
      const value = store.get(key)
      if (value === undefined) return null
      if (type === 'json') return JSON.parse(value)
      return value
    },
    put: async (key: string, value: string) => { store.set(key, value) },
    delete: async (key: string) => { store.delete(key) },
    list: async () => ({ keys: [], list_complete: true, cursor: '' }),
  }
}

function memoryState() {
  const entries = new Map<string, unknown>()
  let queue = Promise.resolve()
  const storage = {
    get: async (key: string) => entries.get(key),
    put: async (key: string, value: unknown) => { entries.set(key, value) },
    setAlarm: vi.fn(async (_time: number) => {}),
    delete: async (key: string) => entries.delete(key),
    deleteAll: async () => { entries.clear() },
    // Model the storage transaction boundary, while running the production DO.
    transaction: <T>(callback: (txn: unknown) => Promise<T>): Promise<T> => {
      const result = queue.then(() => callback(storage))
      queue = result.then(() => {}, () => {})
      return result
    },
  }
  return { storage } as unknown as DurableObjectState
}

function memoryAuthorizationStates(): DurableObjectNamespace {
  const objects = new Map<string, AuthorizationState>()
  return {
    idFromName: (name: string) => name,
    get: (id: string) => {
      if (!objects.has(id)) objects.set(id, new AuthorizationState(memoryState()))
      return { fetch: (input: string, init?: RequestInit) => objects.get(id)!.fetch(new Request(input, init)) }
    },
  } as unknown as DurableObjectNamespace
}

function requestFor(clientId: string, redirectUri: string, scope: string[]): AuthRequest {
  return {
    responseType: 'code',
    clientId,
    redirectUri,
    scope,
    state: 'client-state',
    issuer: 'https://lmr-mcp.edmundlim.systems',
  }
}

function client(partial: Pick<ClientInfo, 'clientId' | 'clientName' | 'redirectUris'>): ClientInfo {
  return { tokenEndpointAuthMethod: 'none', ...partial }
}

describe('consent and grants', () => {
  it('shows each client before Allow, denies without an unregistered redirect, and keeps grants owner-scoped', async () => {
    const kv = memoryKv()
    const states = memoryAuthorizationStates()
    const seed = (state: string, request: AuthRequest) => states.get(states.idFromName(state)).fetch(
      'https://authorization-state/pending', { method: 'PUT', body: JSON.stringify(request) },
    )
    const clients = new Map<string, ClientInfo>([
      ['grok', client({ clientId: 'grok', clientName: 'Grok', redirectUris: ['https://grok.example/callback'] })],
      ['cursor', client({ clientId: 'cursor', clientName: 'Cursor', redirectUris: ['cursor://anysphere.cursor-mcp/oauth/callback'] })],
      ['web', client({ clientId: 'web', clientName: 'Web', redirectUris: ['https://app.example/callback'] })],
    ])
    await seed(STATE_GROK, requestFor('grok', 'https://grok.example/callback', ['board']))
    await seed(STATE_CURSOR, requestFor('cursor', 'cursor://anysphere.cursor-mcp/oauth/callback', ['board']))
    await seed(STATE_HTTP, requestFor('web', 'http://evil.example/callback', ['board']))
    await seed(STATE_PLAIN, requestFor('grok', 'https://grok.example/callback', ['openid']))

    const completed: Array<{ metadata: unknown; props: unknown; scope: string[] }> = []
    const grants: GrantSummary[] = [{
      id: 'grant-a-aaaaaaaa',
      clientId: 'grok',
      userId: USER_A,
      scope: ['board'],
      metadata: { email: 'hidden@example.com' },
      createdAt: 10,
      redirectUri: 'https://grok.example/callback',
    }]
    const revoked: string[] = []
    const oauth = {
      lookupClient: async (id: string) => clients.get(id) ?? null,
      completeAuthorization: async (options: { metadata: unknown; props: unknown; scope: string[] }) => {
        completed.push(options)
        return { redirectTo: 'https://grok.example/callback?code=one' }
      },
      listUserGrants: async (userId: string) => ({ items: grants.filter((grant) => grant.userId === userId) }),
      revokeGrant: async (grantId: string, userId: string) => {
        revoked.push(`${userId}:${grantId}`)
        const index = grants.findIndex((grant) => grant.id === grantId && grant.userId === userId)
        if (index >= 0) grants.splice(index, 1)
      },
    } as unknown as OAuthHelpers

    const deps: IdentityDeps = {
      verifyUser: async (_env, token) => {
        if (token === 'token-a') return { id: USER_A, email: 'a@example.com', fullName: 'A' }
        if (token === 'token-b') return { id: USER_B, email: 'b@example.com', fullName: 'B' }
        return null
      },
      accountExists: async () => true,
    }
    const env = {
      SUPABASE_URL: 'https://example.supabase.co',
      SUPABASE_ANON_KEY: 'anon',
      SUPABASE_SERVICE_ROLE_KEY: 'service',
      WEB_ORIGINS: 'https://lmr.sillyapps.co',
      OAUTH_KV: kv,
      AUTHORIZATION_STATE: states,
      OAUTH_PROVIDER: oauth,
    } as unknown as Env

    function authed(path: string, token: string, init?: RequestInit) {
      const headers = new Headers(init?.headers)
      headers.set('Authorization', `Bearer ${token}`)
      headers.set('Origin', 'https://lmr.sillyapps.co')
      return handlePublicRequest(new Request(`https://lmr-mcp.edmundlim.systems${path}`, { ...init, headers }), env, deps)
    }

    const grok = await authed(`/consent?state=${STATE_GROK}`, 'token-a')
    const cursor = await authed(`/consent?state=${STATE_CURSOR}`, 'token-a')
    expect(grok.status).toBe(200)
    expect(cursor.status).toBe(200)
    const grokBody = await grok.json() as { summary: { client: { name: string }; redirectOrigin: string } }
    const cursorBody = await cursor.json() as { summary: { client: { name: string }; redirectOrigin: string } }
    expect(grokBody.summary.client.name).toBe('Grok')
    expect(grokBody.summary.redirectOrigin).toBe('https://grok.example')
    expect(cursorBody.summary.client.name).toBe('Cursor')
    expect(cursorBody.summary.redirectOrigin).toBe('cursor://anysphere.cursor-mcp')
    expect(grokBody.summary.redirectOrigin).not.toBe(cursorBody.summary.redirectOrigin)

    expect((await authed('/consent?state=not-a-state', 'token-a')).status).toBe(400)
    expect((await authed('/consent?state=99999999-9999-4999-8999-999999999999', 'token-a')).status).toBe(400)
    expect((await authed(`/consent?state=${STATE_HTTP}`, 'token-a')).status).toBe(400)
    const plain = await authed(`/consent?state=${STATE_PLAIN}`, 'token-a')
    expect(plain.status).toBe(400)
    expect(await plain.json()).toMatchObject({ error: 'board_not_requested' })

    const denied = await authed('/consent/deny', 'token-a', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ state: STATE_GROK }),
    })
    expect(denied.status).toBe(200)
    const denial = await denied.json() as { redirectTo: string }
    expect(denial.redirectTo).toContain('https://grok.example/callback')
    expect(denial.redirectTo).toContain('error=access_denied')
    expect((await authed(`/consent?state=${STATE_GROK}`, 'token-a')).status).toBe(400)
    expect((await authed('/bind', 'token-a', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ state: STATE_GROK }),
    })).status).toBe(400)

    const unsafeDeny = await authed('/consent/deny', 'token-a', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ state: STATE_HTTP }),
    })
    const unsafeBody = await unsafeDeny.json() as { redirectTo: string | null }
    expect(unsafeBody.redirectTo).toBeNull()
    expect(JSON.stringify(unsafeBody)).not.toContain('evil.example')

    const bound = await authed('/bind', 'token-a', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ state: STATE_CURSOR }),
    })
    expect(bound.status).toBe(200)
    expect(completed).toHaveLength(1)
    expect(completed[0].metadata).toEqual({})
    expect(completed[0].scope).toEqual(['board'])
    expect(completed[0].props).toEqual({ userId: USER_A, tokenId: 'oauth', agentName: 'Cursor' })
    expect(completed[0].props).not.toHaveProperty('userEmail')

    const listed = await authed('/grants', 'token-a')
    const listedBody = await listed.json() as { grants: Array<{ clientName: string }> }
    expect(listedBody.grants.map((grant) => grant.clientName)).toEqual(['Grok'])
    expect(JSON.stringify(listedBody)).not.toContain('hidden@example.com')

    const foreign = await authed('/grants/revoke', 'token-b', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ grantId: 'grant-a-aaaaaaaa', userId: USER_A }),
    })
    expect(foreign.status).toBe(404)
    expect(revoked).toEqual([])

    const own = await authed('/grants/revoke', 'token-a', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ grantId: 'grant-a-aaaaaaaa' }),
    })
    expect(own.status).toBe(200)
    expect(revoked).toEqual([`${USER_A}:grant-a-aaaaaaaa`])

    const cleanup = await authed('/account/grants/cleanup', 'token-a', { method: 'POST', body: '{}' })
    expect(cleanup.status).toBe(200)
    expect(await cleanup.json()).toMatchObject({ complete: true, remaining: 0 })
  })
})

describe('single-use authorization', () => {
  async function setup(delayedKv = false) {
    const pending = requestFor('grok', 'https://grok.example/callback', ['board'])
    const oauth = {
      parseAuthRequest: async () => pending,
      lookupClient: async () => client({
        clientId: 'grok', clientName: 'Grok', redirectUris: [pending.redirectUri],
      }),
      completeAuthorization: vi.fn(async () => ({ redirectTo: 'https://grok.example/callback?code=one' })),
    }
    const kv = memoryKv()
    if (delayedKv) vi.spyOn(kv, 'get').mockResolvedValue(null)
    const env = {
      WEB_ORIGINS: 'https://lmr.sillyapps.co',
      OAUTH_KV: kv,
      OAUTH_PROVIDER: oauth,
      AUTHORIZATION_STATE: memoryAuthorizationStates(),
    } as unknown as Env
    const deps: IdentityDeps = {
      verifyUser: async () => ({ id: USER_A, email: null, fullName: 'A' }),
      accountExists: async () => true,
    }
    const authorized = await handlePublicRequest(new Request('https://lmr-mcp.edmundlim.systems/authorize'), env, deps)
    expect(authorized.status).toBe(302)
    const state = new URL(authorized.headers.get('Location')!).searchParams.get('state')!
    const post = (path: string) => handlePublicRequest(new Request(`https://lmr-mcp.edmundlim.systems${path}`, {
      method: 'POST',
      headers: { Authorization: 'Bearer token-a', Origin: 'https://lmr.sillyapps.co', 'Content-Type': 'application/json' },
      body: JSON.stringify({ state }),
    }), env, deps)
    const consent = () => handlePublicRequest(new Request(`https://lmr-mcp.edmundlim.systems/consent?state=${state}`, {
      headers: { Authorization: 'Bearer token-a' },
    }), env, deps)
    return { kv, oauth, pending, state, consent, bind: () => post('/bind'), deny: () => post('/consent/deny') }
  }

  it('reads fresh consent and binds despite delayed KV visibility after authorization succeeds', async () => {
    const { consent, bind, oauth } = await setup(true)
    const response = await consent()
    expect(response.status).toBe(200)
    expect(await response.json()).toMatchObject({ summary: { client: { name: 'Grok' } } })
    expect((await bind()).status).toBe(200)
    expect(oauth.completeAuthorization).toHaveBeenCalledTimes(1)
  })

  it('denial removes pending consent and prevents a grant even with stale KV', async () => {
    const { kv, oauth, pending, consent, bind, deny } = await setup()
    expect(await (await deny()).json()).toEqual({ redirectTo: expect.stringContaining('error=access_denied') })
    vi.spyOn(kv, 'get').mockResolvedValue(pending)
    expect((await consent()).status).toBe(400)
    expect(await (await bind()).json()).toEqual({ error: 'expired_state' })
    expect(oauth.completeAuthorization).not.toHaveBeenCalled()
    expect((await deny()).status).toBe(200)
  })

  it('creates exactly one grant when both authenticated binds read the same pending state', async () => {
    const { oauth, bind } = await setup()
    const lookup = oauth.lookupClient
    let release!: () => void
    const bothRead = new Promise<void>((resolve) => { release = resolve })
    let reads = 0
    vi.spyOn(oauth, 'lookupClient').mockImplementation(async () => {
      const pending = await lookup()
      if (++reads === 2) release()
      await bothRead
      return pending
    })

    const responses = await Promise.all([bind(), bind()])
    expect(responses.map((response) => response.status).sort()).toEqual([200, 400])
    expect(oauth.completeAuthorization).toHaveBeenCalledTimes(1)
    const loser = responses.find((response) => response.status === 400)!
    expect(await loser.json()).toEqual({ error: 'expired_state' })
    expect(loser.headers.get('Access-Control-Allow-Origin')).toBe('https://lmr.sillyapps.co')
  })

  it('rejects a later replay even if KV returns the deleted pending record', async () => {
    const { kv, oauth, pending, bind } = await setup()
    expect((await bind()).status).toBe(200)
    vi.spyOn(kv, 'get').mockResolvedValue(pending)

    const replay = await bind()
    expect(replay.status).toBe(400)
    expect(await replay.json()).toEqual({ error: 'expired_state' })
    expect(oauth.completeAuthorization).toHaveBeenCalledTimes(1)
  })

  it('completes the normal authorize/bind flow and removes the pending record', async () => {
    const { consent, oauth, bind } = await setup()
    const response = await bind()
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ redirectTo: 'https://grok.example/callback?code=one' })
    expect(oauth.completeAuthorization).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({
      userId: USER_A, scope: ['board'], props: { userId: USER_A, tokenId: 'oauth', agentName: 'Grok' },
    }))
    expect((await consent()).status).toBe(400)
    expect(await (await bind()).json()).toEqual({ error: 'expired_state' })
  })

  it('expires pending reads and consumption at ten minutes even before alarm cleanup', async () => {
    const now = Date.now()
    const clock = vi.spyOn(Date, 'now').mockReturnValue(now)
    try {
      const { consent, bind, oauth } = await setup()
      clock.mockReturnValue(now + PENDING_AUTH_TTL_SECONDS * 1000 - 1)
      expect((await consent()).status).toBe(200)
      clock.mockReturnValue(now + PENDING_AUTH_TTL_SECONDS * 1000)
      expect(await (await consent()).json()).toEqual({ error: 'expired_state' })
      expect(await (await bind()).json()).toEqual({ error: 'expired_state' })
      expect(oauth.completeAuthorization).not.toHaveBeenCalled()

      const storage = memoryState()
      clock.mockReturnValue(now)
      const object = new AuthorizationState(storage)
      await object.fetch(new Request('https://authorization-state/pending', {
        method: 'PUT', body: JSON.stringify(requestFor('grok', 'https://grok.example/callback', ['board'])),
      }))
      clock.mockReturnValue(now + PENDING_AUTH_TTL_SECONDS * 1000)
      expect(await (await object.fetch(new Request('https://authorization-state/consume', { method: 'POST' }))).json())
        .toEqual({ consumed: false })
      await object.alarm()
      expect(await storage.storage.get('pending')).toBeUndefined()
    } finally {
      clock.mockRestore()
    }
  })

  it('persists consumption across object instances and schedules cleanup after ten minutes', async () => {
    const state = memoryState()
    const before = Date.now()
    const object = new AuthorizationState(state)
    const pending = requestFor('grok', 'https://grok.example/callback', ['board'])
    await object.fetch(new Request('https://authorization-state/pending', { method: 'PUT', body: JSON.stringify(pending) }))
    const consume = () => new Request('https://authorization-state/consume', { method: 'POST' })
    expect(await (await new AuthorizationState(state).fetch(new Request('https://authorization-state/pending'))).json()).toEqual(pending)
    expect(await (await object.fetch(consume())).json()).toEqual({ consumed: true })
    const expiry = vi.mocked(state.storage.setAlarm).mock.calls[0][0] as number
    expect(expiry).toBeGreaterThanOrEqual(before + PENDING_AUTH_TTL_SECONDS * 1000)
    expect(expiry).toBeLessThanOrEqual(Date.now() + PENDING_AUTH_TTL_SECONDS * 1000)

    const restarted = new AuthorizationState(state)
    expect(await (await restarted.fetch(consume())).json()).toEqual({ consumed: false })
    expect(state.storage.setAlarm).toHaveBeenCalledTimes(1)
    expect(await (await restarted.fetch(new Request('https://authorization-state/pending'))).json()).toBeNull()
    await restarted.alarm()
    expect(await state.storage.get('consumed')).toBeUndefined()
  })
})
