import { describe, expect, it } from 'vitest'
import { MCP_HOSTS, MCP_RESOURCE, mcpResourceForRequest } from './constants'
import { corsHeaders, handlePublicRequest, resolveExternalPat, serverCard } from './oauth'

const env = {
  WEB_ORIGINS: 'https://lmr.sillyapps.co,http://localhost:5173',
} as Env

describe('mcpResourceForRequest', () => {
  it.each([...MCP_HOSTS])('uses the request host %s as the PAT audience', (host) => {
    expect(mcpResourceForRequest(new Request(`https://${host}/mcp`))).toBe(`https://${host}/mcp`)
  })

  it('falls back to the canonical resource for an unknown host', () => {
    expect(mcpResourceForRequest(new Request('https://evil.example/mcp'))).toBe(MCP_RESOURCE)
  })
})

describe('bind CORS', () => {
  it.each([
    'https://np.sillyapps.co',
    'https://lmr.sillyapps.co',
  ])('allows the live web origin %s', (origin) => {
    const headers = corsHeaders(
      new Request('https://np-mcp.sillyapps.co/bind', {
        headers: { Origin: origin },
      }),
      { WEB_ORIGINS: 'https://np.sillyapps.co,https://lmr.sillyapps.co,http://localhost:5173' } as Env,
    )
    expect(headers['Access-Control-Allow-Origin']).toBe(origin)
  })

  it('still allows the older lmr.edmundlim.systems alias', () => {
    const headers = corsHeaders(
      new Request('https://lmr-mcp.edmundlim.systems/bind', {
        headers: { Origin: 'https://lmr.edmundlim.systems' },
      }),
      { WEB_ORIGINS: 'https://np.sillyapps.co,https://lmr.sillyapps.co,https://lmr.edmundlim.systems' } as Env,
    )
    expect(headers['Access-Control-Allow-Origin']).toBe('https://lmr.edmundlim.systems')
  })

  it('ignores unknown origins', () => {
    const headers = corsHeaders(
      new Request('https://lmr-mcp.edmundlim.systems/bind', {
        headers: { Origin: 'https://evil.example' },
      }),
      env,
    )
    expect(headers['Access-Control-Allow-Origin']).toBeUndefined()
  })
})

describe('serverCard', () => {
  it('keeps oauth-only auth without invented dual-auth fields', () => {
    const card = serverCard()
    expect(card.auth).toEqual({ type: 'oauth' })
    expect(card).not.toHaveProperty('authentication')
    expect(card).not.toHaveProperty('authTypes')
    expect(Object.keys(card.auth)).toEqual(['type'])
  })
})

describe('resolveExternalPat', () => {
  it('returns null for bearer tokens that are not personal agent keys', async () => {
    const result = await resolveExternalPat({
      token: 'not-an-lmr-pat',
      request: new Request('https://lmr-mcp.edmundlim.systems/mcp'),
      env: {
        ...env,
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
      } as Env,
    })
    expect(result).toBeNull()
  })
})
