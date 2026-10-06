import type { AuthRequest, ClientInfo, GrantSummary, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it } from 'vitest'
import { handlePublicRequest } from './oauth'
import type { IdentityDeps } from './supabaseUser'

const USER_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const USER_B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
const STATE_GROK = '11111111-1111-4111-8111-111111111111'
const STATE_CURSOR = '22222222-2222-4222-8222-222222222222'
const STATE_HTTP = '33333333-3333-4333-8333-333333333333'
const STATE_PLAIN = '44444444-4444-4444-8444-444444444444'

function memoryKv(): KVNamespace {
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
  } as unknown as KVNamespace
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
      WEB_ORIGINS: 'https://lmr.edmundlim.systems',
      OAUTH_KV: kv,
      OAUTH_PROVIDER: oauth,
    } as unknown as Env

    function authed(path: string, token: string, init?: RequestInit) {
      const headers = new Headers(init?.headers)
      headers.set('Authorization', `Bearer ${token}`)
      headers.set('Origin', 'https://lmr.edmundlim.systems')
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
