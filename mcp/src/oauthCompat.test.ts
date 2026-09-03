import { describe, expect, it } from 'vitest'
import { prepareOauthRequest, rewriteOauthPath } from './oauthCompat'

describe('rewriteOauthPath', () => {
  it('aliases path-aware and OpenID discovery URLs onto RFC 8414 metadata', () => {
    expect(rewriteOauthPath('/.well-known/oauth-authorization-server/mcp')).toBe(
      '/.well-known/oauth-authorization-server',
    )
    expect(rewriteOauthPath('/.well-known/oauth-authorization-server/mcp/')).toBe(
      '/.well-known/oauth-authorization-server',
    )
    expect(rewriteOauthPath('/.well-known/openid-configuration')).toBe(
      '/.well-known/oauth-authorization-server',
    )
    expect(rewriteOauthPath('/.well-known/openid-configuration/mcp')).toBe(
      '/.well-known/oauth-authorization-server',
    )
  })

  it('strips trailing slashes on OAuth endpoints without touching other paths', () => {
    expect(rewriteOauthPath('/token/')).toBe('/token')
    expect(rewriteOauthPath('/authorize/')).toBe('/authorize')
    expect(rewriteOauthPath('/register/')).toBe('/register')
    expect(rewriteOauthPath('/bind/')).toBe('/bind')
    expect(rewriteOauthPath('/mcp/')).toBe('/mcp')
    expect(rewriteOauthPath('/')).toBe('/')
    expect(rewriteOauthPath('/.well-known/oauth-authorization-server')).toBe(
      '/.well-known/oauth-authorization-server',
    )
  })
})

describe('prepareOauthRequest', () => {
  it('rewrites JSON token posts to form-urlencoded without touching MCP JSON-RPC', async () => {
    const token = await prepareOauthRequest(
      new Request('https://lmr-mcp.edmundlim.systems/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify({
          grant_type: 'authorization_code',
          code: 'abc',
          redirect_uri: 'https://grok.com/connectors-oauth-exchange-code/',
          client_id: 'grok',
          code_verifier: 'verifier',
          resource: ['https://lmr-mcp.edmundlim.systems/mcp'],
        }),
      }),
    )
    expect(token.headers.get('Content-Type')).toBe('application/x-www-form-urlencoded')
    const body = await token.text()
    const params = new URLSearchParams(body)
    expect(params.get('grant_type')).toBe('authorization_code')
    expect(params.get('code')).toBe('abc')
    expect(params.get('code_verifier')).toBe('verifier')
    expect(params.get('resource')).toBe('https://lmr-mcp.edmundlim.systems/mcp')

    const mcp = new Request('https://lmr-mcp.edmundlim.systems/mcp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize' }),
    })
    const preparedMcp = await prepareOauthRequest(mcp)
    expect(preparedMcp.headers.get('Content-Type')).toBe('application/json')
    expect(await preparedMcp.text()).toContain('initialize')
  })

  it('does not rewrite form-urlencoded token posts', async () => {
    const request = new Request('https://lmr-mcp.edmundlim.systems/token/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'grant_type=refresh_token&refresh_token=r1',
    })
    const prepared = await prepareOauthRequest(request)
    expect(new URL(prepared.url).pathname).toBe('/token')
    expect(prepared.headers.get('Content-Type')).toBe('application/x-www-form-urlencoded')
    expect(await prepared.text()).toBe('grant_type=refresh_token&refresh_token=r1')
  })
})
