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
      return objects.get(id)
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
    const clients = new Map<string, ClientInfo>([
      ['grok', client({ clientId: 'grok', clientName: 'Grok', redirectUris: ['https://grok.example/callback'] })],
      ['cursor', client({ clientId: 'cursor', clientName: 'Cursor', redirectUris: ['cursor://anysphere.cursor-mcp/oauth/callback'] })],
      ['web', client({ clientId: 'web', clientName: 'Web', redirectUris: ['https://app.example/callback'] })],
    ])
    await kv.put('pending-auth:' + STATE_GROK, JSON.stringify(requestFor('grok', 'https://grok.example/callback', ['board'])))
    await kv.put('pending-auth:' + STATE_CURSOR, JSON.stringify(requestFor('cursor', 'cursor://anysphere.cursor-mcp/oauth/callback', ['board'])))
    await kv.put('pending-auth:' + STATE_HTTP, JSON.stringify(requestFor('web', 'http://evil.example/callback', ['board'])))
    await kv.put('pending-auth:' + STATE_PLAIN, JSON.stringify(requestFor('grok', 'https://grok.example/callback', ['openid'])))

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
      AUTHORIZATION_STATE: memoryAuthorizationStates(),
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
    expect(await kv.get('pending-auth:' + STATE_GROK)).toBeNull()
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
  async function setup() {
    const pending = requestFor('grok', 'https://grok.example/callback', ['board'])
    const oauth = {
      parseAuthRequest: async () => pending,
      lookupClient: async () => client({
        clientId: 'grok', clientName: 'Grok', redirectUris: [pending.redirectUri],
      }),
      completeAuthorization: vi.fn(async () => ({ redirectTo: 'https://grok.example/callback?code=one' })),
    }
    const kv = memoryKv()
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
    return { kv, oauth, pending, state, bind: () => post('/bind'), deny: () => post('/consent/deny') }
  }

  it.each([true, false])('denial prevents a grant from stale KV (pending at denial: %s)', async (hasPending) => {
    const { kv, oauth, pending, state, bind, deny } = await setup()
    if (!hasPending) await kv.delete('pending-auth:' + state)

    const denied = await deny()
    expect(denied.status).toBe(200)
    expect(await denied.json()).toEqual({
      redirectTo: hasPending ? expect.stringContaining('error=access_denied') : null,
    })
    expect(await kv.get('pending-auth:' + state)).toBeNull()
    vi.spyOn(kv, 'get').mockResolvedValue(pending)

    const replay = await bind()
    expect(replay.status).toBe(400)
    expect(await replay.json()).toEqual({ error: 'expired_state' })
    expect(oauth.completeAuthorization).not.toHaveBeenCalled()
    const repeatedDenial = await deny()
    expect(repeatedDenial.status).toBe(400)
    expect(await repeatedDenial.json()).toEqual({ error: 'expired_state' })
  })

  it('rejects denial when approval wins after denial reads the pending state', async () => {
    const { kv, oauth, bind, deny } = await setup()
    const get = kv.get.bind(kv)
    let markRead!: () => void
    const denialRead = new Promise<void>((resolve) => { markRead = resolve })
    let release!: () => void
    const resumeDenial = new Promise<void>((resolve) => { release = resolve })
    vi.spyOn(kv, 'get').mockImplementationOnce(async (key: string) => {
      const pending = await get(key, 'json')
      markRead()
      await resumeDenial
      return pending
    })
    const deletePending = vi.spyOn(kv, 'delete')

    const denial = deny()
    await denialRead
    try {
      const approval = await bind()
      expect(approval.status).toBe(200)
      expect(await approval.json()).toEqual({ redirectTo: 'https://grok.example/callback?code=one' })
    } finally {
      release()
    }

    const denied = await denial
    expect(denied.status).toBe(400)
    expect(await denied.json()).toEqual({ error: 'expired_state' })
    expect(denied.headers.get('Access-Control-Allow-Origin')).toBe('https://lmr.sillyapps.co')
    expect(oauth.completeAuthorization).toHaveBeenCalledTimes(1)
    expect(deletePending).toHaveBeenCalledTimes(1)
  })

  it('creates exactly one grant when both authenticated binds read the same pending state', async () => {
    const { kv, oauth, bind } = await setup()
    const get = kv.get.bind(kv)
    let release!: () => void
    const bothRead = new Promise<void>((resolve) => { release = resolve })
    let reads = 0
    vi.spyOn(kv, 'get').mockImplementation(async (key: string) => {
      const pending = await get(key, 'json')
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
    const { kv, oauth, state, bind } = await setup()
    const response = await bind()
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ redirectTo: 'https://grok.example/callback?code=one' })
    expect(oauth.completeAuthorization).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({
      userId: USER_A, scope: ['board'], props: { userId: USER_A, tokenId: 'oauth', agentName: 'Grok' },
    }))
    expect(await kv.get('pending-auth:' + state)).toBeNull()
    expect(await (await bind()).json()).toEqual({ error: 'expired_state' })
  })

  it('persists consumption across object instances and schedules cleanup after ten minutes', async () => {
    const state = memoryState()
    const before = Date.now()
    const object = new AuthorizationState(state)
    expect(await (await object.fetch()).json()).toEqual({ consumed: true })
    const expiry = vi.mocked(state.storage.setAlarm).mock.calls[0][0] as number
    expect(expiry).toBeGreaterThanOrEqual(before + PENDING_AUTH_TTL_SECONDS * 1000)
    expect(expiry).toBeLessThanOrEqual(Date.now() + PENDING_AUTH_TTL_SECONDS * 1000)

    const restarted = new AuthorizationState(state)
    expect(await (await restarted.fetch()).json()).toEqual({ consumed: false })
    expect(state.storage.setAlarm).toHaveBeenCalledTimes(1)
    await restarted.alarm()
    expect(await state.storage.get('consumed')).toBeUndefined()
  })
})
