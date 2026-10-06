import { describe, expect, it } from 'vitest'
import { redirectUriAllowed, redirectUriRegistered, registrationRedirectError } from './redirects'

describe('redirectUriAllowed', () => {
  it('allows https, loopback http, and private app schemes', () => {
    expect(redirectUriAllowed('https://grok.example/callback')).toBe(true)
    expect(redirectUriAllowed('http://127.0.0.1:33418/callback')).toBe(true)
    expect(redirectUriAllowed('http://localhost:3000/callback')).toBe(true)
    expect(redirectUriAllowed('cursor://anysphere.cursor-mcp/oauth/callback')).toBe(true)
  })

  it('rejects public http and dangerous schemes', () => {
    expect(redirectUriAllowed('http://evil.example/callback')).toBe(false)
    expect(redirectUriAllowed('javascript:alert(1)')).toBe(false)
    expect(redirectUriAllowed('data:text/html,hi')).toBe(false)
  })
})

describe('registrationRedirectError', () => {
  it('rejects a public http registration and keeps a native scheme', () => {
    expect(registrationRedirectError({
      redirect_uris: ['http://evil.example/callback'],
    })?.description).toContain('https')
    expect(registrationRedirectError({
      redirect_uris: ['cursor://anysphere.cursor-mcp/oauth/callback'],
    })).toBeUndefined()
  })
})

describe('redirectUriRegistered', () => {
  it('ignores loopback port and refuses an unregistered or public http uri', () => {
    const registered = ['http://127.0.0.1:1/callback', 'https://grok.example/callback']
    expect(redirectUriRegistered('http://127.0.0.1:65535/callback', registered)).toBe(true)
    expect(redirectUriRegistered('https://grok.example/callback', registered)).toBe(true)
    expect(redirectUriRegistered('https://evil.example/callback', registered)).toBe(false)
    expect(redirectUriRegistered('http://evil.example/callback', ['http://evil.example/callback'])).toBe(false)
  })
})
