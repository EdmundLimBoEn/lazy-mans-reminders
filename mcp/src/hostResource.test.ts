import { afterEach, describe, expect, it, vi } from 'vitest'
import { setup } from '../test/oauthWorker'
import { MCP_HOSTS, MCP_RESOURCE } from './constants'
import type { TokenSecret } from './domain'
import { hashSecret } from './token'

// Keep the real worker/provider authentication and OAuth flow; stub only MCP transport.
vi.mock('agents/mcp/server', () => ({
  createMcpHandler: () => ({ fetch: async () => Response.json({ accepted: true }) }),
}))

const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const REDIRECT = 'https://client.example/callback'
const VERIFIER = 'a'.repeat(43)

afterEach(() => vi.unstubAllGlobals())

describe('worker resource binding across supported hosts', () => {
  it.each(MCP_HOSTS)('advertises and accepts a valid personal token on %s', async (host) => {
    const { request } = setup()
    const metadata = await request(host, '/.well-known/oauth-protected-resource/mcp')
    expect(await metadata.json()).toMatchObject({ resource: `https://${host}/mcp` })
    const token_hash = await hashSecret('test-secret' as TokenSecret)
    vi.stubGlobal('fetch', async (_input: unknown, init?: RequestInit) => init?.method === 'PATCH'
      ? new Response(null, { status: 204 })
      : Response.json({ id: USER, user_id: USER, name: 'Test', token_hash, revoked_at: null }))
    const response = await request(host, '/mcp', { headers: { Authorization: `Bearer lmr_${USER}_test-secret` } })
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ accepted: true })
  })

  it('does not advertise an arbitrary request host as a supported resource', async () => {
    const { request } = setup()
    const response = await request('evil.example', '/.well-known/oauth-protected-resource/mcp')
    expect(await response.json()).toMatchObject({ resource: MCP_RESOURCE })
  })

  it.each(MCP_HOSTS)('keeps %s grants usable after consent completes on the other host', async (host) => {
    const { request, post, env } = setup()
    const otherHost = MCP_HOSTS.find((candidate) => candidate !== host)!
    const resource = `https://${host}/mcp`
    const registered = await post(host, '/register', {
      client_name: 'Test client', redirect_uris: [REDIRECT], token_endpoint_auth_method: 'none',
      grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'],
    })
    expect(registered.status).toBe(201)
    const { client_id } = await registered.json() as { client_id: string }
    const challenge = Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(VERIFIER))).toString('base64url')
    const params = new URLSearchParams({
      client_id, redirect_uri: REDIRECT, response_type: 'code', scope: 'board', state: 'client-state',
      code_challenge: challenge, code_challenge_method: 'S256',
    })
    // Omitted resource must still be pinned and persisted to the initiating host.
    const authorized = await request(host, `/authorize?${params}`)
    expect(authorized.status).toBe(302)
    const state = new URL(authorized.headers.get('Location')!).searchParams.get('state')!
    const pending = await env.AUTHORIZATION_STATE.get(env.AUTHORIZATION_STATE.idFromName(state)).fetch('https://authorization-state/pending')
    expect(await pending.json()).toMatchObject({ resource })
    const consent = await request(otherHost, `/consent?state=${state}`, { headers: { Authorization: 'Bearer test-session' } })
    expect(consent.status).toBe(200)
    const bound = await post(otherHost, '/bind', { state, resource: `https://${otherHost}/mcp` })
    expect(bound.status).toBe(200)
    const { redirectTo } = await bound.json() as { redirectTo: string }
    const code = new URL(redirectTo).searchParams.get('code')!
    const exchanged = await post(host, '/token', {
      grant_type: 'authorization_code', client_id, code, redirect_uri: REDIRECT, code_verifier: VERIFIER,
    })
    expect(exchanged.status).toBe(200)
    const tokens = await exchanged.json() as { access_token: string; refresh_token: string; resource: string }
    expect(tokens.resource).toBe(resource)
    expect(tokens.refresh_token).toBeTruthy()
    const access = (target: string, token: string) => request(target, '/mcp', { headers: { Authorization: `Bearer ${token}` } })
    expect((await access(host, tokens.access_token)).status).toBe(200)
    expect((await access(otherHost, tokens.access_token)).status).toBe(401)
    const refresh = { grant_type: 'refresh_token', client_id, refresh_token: tokens.refresh_token }
    expect((await post(otherHost, '/token', refresh)).status).toBe(400)
    expect((await post(host, '/token', { ...refresh, resource: 'https://evil.example/mcp' })).status).toBe(400)
    const refreshed = await post(host, '/token', refresh)
    expect(refreshed.status).toBe(200)
    const next = await refreshed.json() as { access_token: string; resource: string }
    expect(next.resource).toBe(resource)
    expect((await access(host, next.access_token)).status).toBe(200)
    expect((await access(otherHost, next.access_token)).status).toBe(401)
    expect((await post(otherHost, '/bind', { state })).status).toBe(400)

    // Explicit foreign audiences remain rejected before pending consent is created.
    for (const target of [`https://${otherHost}/mcp`, 'https://evil.example/mcp']) {
      params.set('resource', target)
      const rejected = await request(host, `/authorize?${params}`)
      expect(new URL(rejected.headers.get('Location')!).searchParams.get('error')).toBe('invalid_target')
    }
  })
})
