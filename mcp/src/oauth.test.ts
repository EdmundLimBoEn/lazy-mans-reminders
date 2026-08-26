import { describe, expect, it } from 'vitest'
import { corsHeaders } from './oauth'

const env = {
  WEB_ORIGINS: 'https://lmr.edmundlim.systems,http://localhost:5173',
} as Env

describe('bind CORS', () => {
  it('allows the web origin', () => {
    const headers = corsHeaders(
      new Request('https://mcp.lmr.edmundlim.systems/bind', {
        headers: { Origin: 'https://lmr.edmundlim.systems' },
      }),
      env,
    )
    expect(headers['Access-Control-Allow-Origin']).toBe('https://lmr.edmundlim.systems')
  })

  it('ignores unknown origins', () => {
    const headers = corsHeaders(
      new Request('https://mcp.lmr.edmundlim.systems/bind', {
        headers: { Origin: 'https://evil.example' },
      }),
      env,
    )
    expect(headers['Access-Control-Allow-Origin']).toBeUndefined()
  })
})
