import { afterEach, describe, expect, it, vi } from 'vitest'
import { handleWorkerFetch } from './index'
import { handlePublicRequest } from './oauth'
import { prepareOauthRequest } from './oauthCompat'

const { providerFetch } = vi.hoisted(() => ({ providerFetch: vi.fn(async () => new Response(null, { status: 400 })) }))
vi.mock('@cloudflare/workers-oauth-provider', () => ({
  OAuthProvider: class { fetch = providerFetch },
  OAuthError: class extends Error {},
  getOAuthApi: vi.fn(),
}))

vi.mock('agents/mcp/server', () => ({ createMcpHandler: vi.fn() }))
vi.mock('./server', () => ({ createServer: vi.fn() }))

afterEach(() => vi.unstubAllGlobals())

describe('JSON body limit', () => {
  it.each([undefined, '1'])('rejects streamed token bodies regardless of Content-Length (%s)', async (contentLength) => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    const cancel = vi.fn()
    const chunks = [
      new TextEncoder().encode('{"code":"'),
      new TextEncoder().encode('é'.repeat(8192)),
      new TextEncoder().encode('"}'),
    ]
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        const chunk = chunks.shift()
        if (chunk) controller.enqueue(chunk)
        else controller.close()
      },
      cancel,
    })
    const headers = new Headers({ 'Content-Type': 'application/json' })
    if (contentLength) headers.set('Content-Length', contentLength)
    const request = new Request('https://lmr-mcp.edmundlim.systems/token/', {
      method: 'POST', headers, body, duplex: 'half',
    } as RequestInit)
    const deps = { verifyUser: vi.fn(), accountExists: vi.fn() }
    const response = await handleWorkerFetch(request, {
      WEB_ORIGINS: 'https://lmr.sillyapps.co',
      AUTH_RATE_LIMIT: { limit: async () => ({ success: true }) },
    } as unknown as Env, {} as ExecutionContext, deps)
    expect(response.status).toBe(413)
    expect(await response.json()).toEqual({ error: 'invalid_body' })
    expect(cancel).toHaveBeenCalledOnce()
    expect(fetch).not.toHaveBeenCalled()
    expect(providerFetch).not.toHaveBeenCalled()
    expect(deps.verifyUser).not.toHaveBeenCalled()
    expect(deps.accountExists).not.toHaveBeenCalled()
  })

  it('accepts a token JSON body exactly at the byte limit', async () => {
    const body = JSON.stringify({ code: 'a'.repeat(16 * 1024 - 11) })
    const prepared = await prepareOauthRequest(new Request('https://example.com/token', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body,
    }))
    expect(prepared).toBeInstanceOf(Request)
    expect(new URLSearchParams(await prepared.text()).get('code')).toBe('a'.repeat(16 * 1024 - 11))
  })

  it('rejects oversized bind JSON with the existing error shape and CORS', async () => {
    const get = vi.fn()
    const response = await handlePublicRequest(new Request('https://example.com/bind', {
      method: 'POST',
      headers: { Authorization: 'Bearer test', Origin: 'https://lmr.sillyapps.co' },
      body: JSON.stringify({ state: '11111111-1111-4111-8111-111111111111', padding: 'a'.repeat(16384) }),
    }), {
      WEB_ORIGINS: 'https://lmr.sillyapps.co', OAUTH_PROVIDER: {}, OAUTH_KV: { get },
    } as unknown as Env, {
      verifyUser: async () => ({ id: 'user', email: null, fullName: '' }),
      accountExists: vi.fn(),
    })
    expect(response.status).toBe(413)
    expect(await response.json()).toEqual({ error: 'invalid_body' })
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://lmr.sillyapps.co')
    expect(get).not.toHaveBeenCalled()
  })
})
