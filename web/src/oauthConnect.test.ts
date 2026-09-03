import { describe, expect, it } from 'vitest'
import { bindFailureMessage, isEmbeddedBrowser, isSafeOauthRedirect } from './oauthConnect'

describe('isEmbeddedBrowser', () => {
  it('detects in-app browsers that partition PKCE storage', () => {
    expect(isEmbeddedBrowser('Mozilla/5.0 (iPhone) AppleWebKit Grok/1.0 Mobile')).toBe(true)
    expect(isEmbeddedBrowser('Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit Chrome')).toBe(true)
    expect(isEmbeddedBrowser('Mozilla/5.0 (iPhone) AppleWebKit FBAN/FBIOS')).toBe(true)
    expect(
      isEmbeddedBrowser(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
      ),
    ).toBe(false)
  })
})

describe('isSafeOauthRedirect', () => {
  it('allows agent callbacks and rejects script URLs', () => {
    expect(isSafeOauthRedirect('https://grok.com/connectors-oauth-exchange-code/?code=x')).toBe(true)
    expect(isSafeOauthRedirect('http://127.0.0.1:8787/callback')).toBe(true)
    expect(isSafeOauthRedirect('cursor://anysphere.cursor-mcp/oauth/callback')).toBe(true)
    expect(isSafeOauthRedirect('javascript:alert(1)')).toBe(false)
    expect(isSafeOauthRedirect('data:text/html,hi')).toBe(false)
    expect(isSafeOauthRedirect('/relative')).toBe(false)
  })
})

describe('bindFailureMessage', () => {
  it('explains expired and unauthorized bind errors', () => {
    expect(bindFailureMessage('expired_state')).toContain('expired')
    expect(bindFailureMessage('unauthorized')).toContain('this window')
    expect(bindFailureMessage('nope')).toContain('Try signing in again')
  })
})
