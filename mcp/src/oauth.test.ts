import { describe, expect, it } from 'vitest'
import { corsHeaders, serverCard } from './oauth'

const env = {
  WEB_ORIGINS: 'https://lmr.edmundlim.systems,http://localhost:5173',
} as Env

describe('bind CORS', () => {
  it('allows the web origin', () => {
    const headers = corsHeaders(
      new Request('https://lmr-mcp.edmundlim.systems/bind', {
        headers: { Origin: 'https://lmr.edmundlim.systems' },
      }),
      env,
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
