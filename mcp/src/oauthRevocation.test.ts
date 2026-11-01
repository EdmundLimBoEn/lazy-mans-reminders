import { describe, expect, it, vi } from 'vitest'
import { setup } from '../test/oauthWorker'

// Exercise the installed provider's actual crypto, token issuance and revocation.
vi.mock('agents/mcp/server', () => ({
  createMcpHandler: () => ({ fetch: async () => Response.json({ accepted: true }) }),
}))

const HOST = 'lmr-mcp.edmundlim.systems'
const REDIRECT = 'https://client.example/callback'
const VERIFIER = 'a'.repeat(43)

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
  return { ...worker, tokens, grantId, refresh, access }
}

describe('revocation during refresh', () => {
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
