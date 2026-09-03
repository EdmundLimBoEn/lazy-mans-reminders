import { describe, expect, it } from 'vitest'
import {
  pkceCodeFromCallbackUrl,
  pkceFlowIdFromCallbackUrl,
  pkceReturnToFromCallbackUrl,
  safeReturnPath,
} from './pkceCallback'

describe('pkceCodeFromCallbackUrl', () => {
  it('reads the code query param and ignores the rest of the URL', () => {
    expect(
      pkceCodeFromCallbackUrl(
        'https://lmr.edmundlim.systems/auth/callback?code=99e78364-8297-411b-9757-82301dd928dc',
      ),
    ).toBe('99e78364-8297-411b-9757-82301dd928dc')
  })

  it('does not treat the full href as a code', () => {
    const href =
      'https://lmr.edmundlim.systems/auth/callback?code=abc123&return_to=%2Fconnect%3Fstate%3Dx'
    expect(pkceCodeFromCallbackUrl(href)).toBe('abc123')
    expect(pkceCodeFromCallbackUrl(href)).not.toContain('https://')
  })

  it('returns null when no code is present', () => {
    expect(pkceCodeFromCallbackUrl('https://lmr.edmundlim.systems/auth/callback')).toBeNull()
  })

  it('reads a hash code when the query has no code', () => {
    expect(
      pkceCodeFromCallbackUrl(
        'https://lmr.edmundlim.systems/auth/callback?return_to=%2Fconnect#code=from-hash',
      ),
    ).toBe('from-hash')
  })
})

describe('pkceFlowIdFromCallbackUrl', () => {
  it('reads sb_flow_id from query or hash', () => {
    expect(
      pkceFlowIdFromCallbackUrl(
        'https://lmr.edmundlim.systems/auth/callback?code=abc&sb_flow_id=flow-1',
      ),
    ).toBe('flow-1')
    expect(
      pkceFlowIdFromCallbackUrl(
        'https://lmr.edmundlim.systems/auth/callback?code=abc#sb_flow_id=flow-hash',
      ),
    ).toBe('flow-hash')
  })
})

describe('pkceReturnToFromCallbackUrl', () => {
  it('reads return_to so Allow survives a new tab on the same origin', () => {
    expect(
      pkceReturnToFromCallbackUrl(
        'https://lmr.edmundlim.systems/auth/callback?code=abc&return_to=%2Fconnect%3Fstate%3Dx',
      ),
    ).toBe('/connect?state=x')
  })
})

describe('safeReturnPath', () => {
  it('keeps connect paths and rejects open redirects', () => {
    expect(safeReturnPath('/connect?state=abc')).toBe('/connect?state=abc')
    expect(safeReturnPath('https://evil.example/')).toBe('/')
    expect(safeReturnPath('//evil.example')).toBe('/')
  })
})
