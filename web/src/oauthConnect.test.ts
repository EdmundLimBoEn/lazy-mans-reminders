import { describe, expect, it } from 'vitest'
import { bindFailureMessage, isSafeOauthRedirect } from './oauthConnect'

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
