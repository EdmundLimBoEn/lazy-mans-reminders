import { createMcpHandler } from 'agents/mcp/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { setup } from '../test/oauthWorker'
import type { TokenSecret } from './domain'
import { supabaseAccountExistsWith, type IdentityDeps } from './supabaseUser'
import { hashSecret } from './token'

// Exercise the installed provider's actual crypto, token issuance and revocation.
vi.mock('agents/mcp/server', () => ({
  createMcpHandler: vi.fn(() => ({ fetch: async () => Response.json({ accepted: true }) })),
}))

const HOST = 'lmr-mcp.edmundlim.systems'
const REDIRECT = 'https://client.example/callback'
const VERIFIER = 'a'.repeat(43)
const USER_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

function suspendAccount(deps: IdentityDeps) {
  vi.useFakeTimers({ toFake: ['Date'] })
  const expiry = new Date(Date.now() + 60_000)
  vi.spyOn(deps, 'accountExists').mockImplementation(supabaseAccountExistsWith(async (input) => {
    expect(new URL(String(input)).pathname).toBe(`/auth/v1/admin/users/${USER_ID}`)
    return Response.json({ id: USER_ID, banned_until: expiry.toISOString() })
  }))
  return () => vi.setSystemTime(expiry)
}

function deferred() {
  let resolve!: () => void
  const promise = new Promise<void>((done) => { resolve = done })
  return { promise, resolve }
}

async function authorize() {
  const worker = setup()
  const { post, request } = worker
  const registration = await post(HOST, '/register', {
    redirect_uris: [REDIRECT], token_endpoint_auth_method: 'none',
    grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'],
  })
  expect(registration.status).toBe(201)
  const { client_id } = await registration.json() as { client_id: string }
  const challenge = Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(VERIFIER))).toString('base64url')
  const params = new URLSearchParams({
    client_id, redirect_uri: REDIRECT, response_type: 'code', scope: 'board',
    code_challenge: challenge, code_challenge_method: 'S256',
  })
  const authorized = await request(HOST, `/authorize?${params}`)
  expect(authorized.status).toBe(302)
  const state = new URL(authorized.headers.get('Location')!).searchParams.get('state')!
  const bound = await post(HOST, '/bind', { state })
  expect(bound.status).toBe(200)
  const { redirectTo } = await bound.json() as { redirectTo: string }
  const exchange = await post(HOST, '/token', {
    grant_type: 'authorization_code', client_id, redirect_uri: REDIRECT,
    code: new URL(redirectTo).searchParams.get('code'), code_verifier: VERIFIER,
  })
  expect(exchange.status).toBe(200)
  const tokens = await exchange.json() as { access_token: string; refresh_token: string }
  const [, grantId] = tokens.refresh_token.split(':')
  const refresh = (token = tokens.refresh_token) => post(HOST, '/token', {
    grant_type: 'refresh_token', client_id, refresh_token: token,
  })
  const access = (token = tokens.access_token) => request(HOST, '/mcp', {
    headers: { Authorization: `Bearer ${token}` },
  })
  expect((await access()).status).toBe(200)
  return { ...worker, tokens, client_id, grantId, refresh, access }
}

describe('account suspension', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    vi.useRealTimers()
    vi.mocked(createMcpHandler).mockClear()
  })

  it('denies agent keys before the MCP handler runs and accepts the same key at expiry', async () => {
    const { request, deps } = setup()
    const secret = 'test-secret' as TokenSecret
    const tokenHash = await hashSecret(secret)
    vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(new URL(String(input)).pathname).toBe('/rest/v1/agent_tokens')
      if (init?.method === 'PATCH') return new Response(null, { status: 204 })
      return Response.json({ id: USER_ID, user_id: USER_ID, name: 'Test', token_hash: tokenHash, revoked_at: null })
    })
    const access = () => request(HOST, '/mcp', {
      headers: { Authorization: `Bearer lmr_${USER_ID}_${secret}` },
    })
    const expire = suspendAccount(deps)

    expect((await access()).status).toBe(401)
    expect(createMcpHandler).not.toHaveBeenCalled()

    expire()
    expect((await access()).status).toBe(200)
    expect(createMcpHandler).toHaveBeenCalledOnce()
  })

  it('denies OAuth access tokens before the MCP handler runs and accepts the same token at expiry', async () => {
    const { deps, access } = await authorize()
    const expire = suspendAccount(deps)
    vi.mocked(createMcpHandler).mockClear()

    expect((await access()).status).toBe(401)
    expect(createMcpHandler).not.toHaveBeenCalled()

    expire()
    expect((await access()).status).toBe(200)
    expect(createMcpHandler).toHaveBeenCalledOnce()
  })

  it('denies refresh without issuing credentials or revoking the OAuth grant', async () => {
    const { deps, kv, refresh } = await authorize()
    const savedRecords = new Map(kv)
    const expire = suspendAccount(deps)

    const response = await refresh()
    expect(response.status).toBe(503)
    const body = await response.json()
    expect(body).toMatchObject({ error: 'temporarily_unavailable' })
    expect(body).not.toHaveProperty('access_token')
    expect(body).not.toHaveProperty('refresh_token')
    expect(kv.size).toBe(savedRecords.size)
    expect([...savedRecords].every(([key, value]) => kv.get(key) === value)).toBe(true)

    expire()
    expect((await refresh()).status).toBe(200)
  })
})

describe('revocation during refresh', () => {
  it('lets only the grant owner retry a failed grant record deletion', async () => {
    const { post, request, env, deps, kv, grantId, refresh, access } = await authorize()
    const grantKey = `grant:${USER_ID}:${grantId}`
    const deleteKey = env.OAUTH_KV.delete.bind(env.OAUTH_KV)
    let failGrantDelete = true
    const deleteRecord = vi.spyOn(env.OAUTH_KV, 'delete').mockImplementation(async (key) => {
      if (key === grantKey && failGrantDelete) {
        failGrantDelete = false
        throw new Error('KV unavailable')
      }
      await deleteKey(key)
    })
    const revoke = () => post(HOST, '/grants/revoke', { grantId })

    const failed = await revoke()
    expect(failed.status).toBe(503)
    expect(await failed.json()).toEqual({ error: 'grant_revoke_failed' })
    expect(kv.has(grantKey)).toBe(true)
    expect((await access()).status).toBe(401)
    expect((await refresh()).status).toBe(400)

    const list = await request(HOST, '/grants', { headers: { Authorization: 'Bearer test-session' } })
    expect(list.status).toBe(200)
    expect(await list.json()).toEqual({ grants: [] })

    deleteRecord.mockClear()
    vi.spyOn(deps, 'verifyUser').mockResolvedValueOnce({
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', email: null, fullName: 'Other user',
    })
    expect((await revoke()).status).toBe(404)
    expect(deleteRecord).not.toHaveBeenCalled()
    expect(kv.has(grantKey)).toBe(true)

    const retried = await revoke()
    expect(retried.status).toBe(200)
    expect(await retried.json()).toEqual({ revoked: true })
    expect(kv.has(grantKey)).toBe(false)
    expect((await access()).status).toBe(401)
    expect((await refresh()).status).toBe(400)
  })

  it('denies an individually revoked access token despite stale KV while preserving its grant and sibling tokens', async () => {
    const { post, kv, tokens, client_id, refresh, access } = await authorize()
    const rotated = await refresh()
    expect(rotated.status).toBe(200)
    const sibling = await rotated.json() as { access_token: string; refresh_token: string }
    expect((await access()).status).toBe(200)
    expect((await access(sibling.access_token)).status).toBe(200)
    const oldRecords = new Map(kv)
    const revoke = () => post(HOST, '/token', {
      client_id, token: tokens.access_token, token_type_hint: 'access_token',
    })
    expect((await revoke()).status).toBe(200)
    // Simulate a KV location continuing to serve records cached before deletion.
    for (const [key, value] of oldRecords) kv.set(key, value)
    expect((await access()).status).toBe(401)
    expect((await revoke()).status).toBe(200)
    expect((await access(sibling.access_token)).status).toBe(200)
    expect((await refresh(sibling.refresh_token)).status).toBe(200)
    expect((await access()).status).toBe(401)
  })

  it.each(['/grants/revoke', '/account/grants/cleanup'])(
    '%s prevents a refresh paused during account verification from restoring access', async (path) => {
      const { post, deps, kv, grantId, refresh, access } = await authorize()
      const entered = deferred()
      const resume = deferred()
      deps.accountExists.mockImplementationOnce(async () => {
        entered.resolve()
        await resume.promise
        return true
      })
      const pending = refresh()
      await entered.promise
      try {
        const revoked = await post(HOST, path, { grantId })
        expect(revoked.status).toBe(200)
        if (path.endsWith('cleanup')) expect(await revoked.json()).toMatchObject({ complete: true })
      } finally {
        resume.resolve()
      }
      const result = await pending
      expect(result.status).toBe(400)
      expect(await result.json()).toMatchObject({ error: 'invalid_grant' })
      expect([...kv.keys()].filter((key) => key.startsWith('grant:') || key.startsWith('token:'))).toEqual([])
      expect((await access()).status).toBe(401)
      expect((await refresh()).status).toBe(400)
    },
  )

  it('rejects late token persistence after refresh has already saved the rotated grant', async () => {
    const { post, env, grantId, refresh, access } = await authorize()
    const entered = deferred()
    const resume = deferred()
    const get = env.GRANT_STATE.get.bind(env.GRANT_STATE)
    let paused = false
    vi.spyOn(env.GRANT_STATE, 'get').mockImplementation((id) => {
      const stub = get(id)
      return {
        fetch: async (input: string, init?: RequestInit) => {
          const operation = JSON.parse(init!.body as string)
          if (!paused && operation.method === 'put' && operation.key.startsWith('token:')) {
            paused = true
            entered.resolve()
            await resume.promise
          }
          return stub.fetch(input, init)
        },
      } as DurableObjectStub
    })
    const pending = refresh()
    await entered.promise
    try {
      expect((await post(HOST, '/grants/revoke', { grantId })).status).toBe(200)
    } finally {
      resume.resolve()
    }
    expect((await pending).status).toBe(400)
    expect((await access()).status).toBe(401)
    expect((await refresh()).status).toBe(400)
  })

  it('denies revoked credentials even when KV returns stale grant and token records', async () => {
    const { post, kv, grantId, refresh, access } = await authorize()
    const oldRecords = new Map(kv)
    expect((await post(HOST, '/grants/revoke', { grantId })).status).toBe(200)
    for (const [key, value] of oldRecords) kv.set(key, value)
    expect((await access()).status).toBe(401)
    expect((await refresh()).status).toBe(400)
  })

  it('persists revocation performed by the account-deletion token callback', async () => {
    const { deps, kv, refresh, access } = await authorize()
    const oldRecords = new Map(kv)
    deps.accountExists.mockResolvedValueOnce(false)
    expect((await refresh()).status).toBe(400)
    for (const [key, value] of oldRecords) kv.set(key, value)
    expect((await access()).status).toBe(401)
    expect((await refresh()).status).toBe(400)
  })
})
