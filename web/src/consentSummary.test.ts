import { describe, expect, it } from 'vitest'
import { consentCanApprove, parseConsentSummary } from './consentSummary'
import { parseGrantList } from './grantList'

describe('parseConsentSummary', () => {
  it('keeps two clients distinguishable and withholds Allow without board access', () => {
    const grok = parseConsentSummary({
      summary: {
        client: { name: 'Grok' },
        redirectOrigin: 'https://grok.example',
        permissions: ['read', 'add', 'complete', 'reopen'],
      },
    })
    const cursor = parseConsentSummary({
      summary: {
        client: { name: 'Cursor' },
        redirectOrigin: 'cursor://anysphere.cursor-mcp',
        permissions: ['read', 'add', 'complete', 'reopen'],
      },
    })
    expect(grok?.client.name).toBe('Grok')
    expect(grok?.redirectOrigin).not.toBe(cursor?.redirectOrigin)
    expect(consentCanApprove(grok)).toBe(true)
    expect(consentCanApprove(cursor)).toBe(true)
    expect(consentCanApprove(parseConsentSummary({
      summary: { client: { name: 'Grok' }, redirectOrigin: 'https://grok.example', permissions: [] },
    }))).toBe(false)
    expect(parseConsentSummary({
      summary: { client: { name: 'x' }, redirectOrigin: 'javascript:alert(1)', permissions: ['read', 'add', 'complete', 'reopen'] },
    })).toBeNull()
  })
})

describe('parseGrantList', () => {
  it('drops malformed rows and does not require an email field', () => {
    expect(parseGrantList({
      grants: [{
        id: 'abcdefghijklmnop',
        clientName: 'Grok',
        redirectOrigin: 'https://grok.example',
        createdAt: 10,
        expiresAt: null,
      }],
    })).toEqual([{
      id: 'abcdefghijklmnop',
      clientName: 'Grok',
      redirectOrigin: 'https://grok.example',
      createdAt: 10,
      expiresAt: null,
    }])
    expect(parseGrantList({ grants: [{ id: 'short' }] })).toBeNull()
  })
})
