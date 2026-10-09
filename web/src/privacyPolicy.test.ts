import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { PrivacyPage } from './LegalPages'

function privacyText(): string {
  const html = renderToStaticMarkup(createElement(PrivacyPage, { onNavigate: () => {} }))
  return html.replace(/<[^>]+>/g, ' ').replace(/&#x27;|&#39;/g, "'").replace(/\s+/g, ' ')
}

describe('privacy policy disclosures', () => {
  const text = privacyText()

  it('shows the 9 October 2026 revision date', () => {
    expect(text).toContain('Last updated: 9 October 2026')
  })

  it('names the canonical domain and the retired one', () => {
    expect(text).toContain('https://lmr.sillyapps.co')
    expect(text).toMatch(/lmr\.edmundlim\.systems, redirects here/)
  })

  it('describes connected-agent revocation and Apple token revocation attempts', () => {
    expect(text).toContain('revokes every connected-agent grant')
    expect(text).toContain('Sign in with Apple tokens')
  })

  it('distinguishes automatic TestFlight diagnostics from submitted feedback', () => {
    expect(text).toContain('Apple automatically collects and shares crash logs and usage information')
    expect(text).toContain('Feedback and screenshots are shared when you submit them')
    expect(text).not.toContain('only if you choose to send them or opt in')
  })

  it('discloses profile names and reminder delivery through APNs', () => {
    expect(text).toContain('including your name when the provider supplies it')
    expect(text).toContain('device, push-to-start, and Live Activity tokens')
    expect(text).toContain('send reminder text through APNs')
  })

  it('does not promise exact cleanup or guaranteed Apple revocation', () => {
    expect(text).toContain('This cleanup is best effort')
    expect(text).toContain('these follow the providers’ retention settings')
    expect(text).toContain('account deletion does not guarantee Apple authorization has been revoked')
    expect(text).toContain('Deleting the Service account does not delete your Apple or Google account')
  })

  it('discloses optional password authentication without app password storage or credential logs', () => {
    expect(text).toContain('Email/password sign-in (optional).')
    expect(text).toContain('Your email and password are sent to Supabase Auth to authenticate an existing account.')
    expect(text).toContain('We do not log sign-in credentials or persist your password in app storage.')
    expect(text).toContain('Account email and session tokens are handled as described in this policy.')
  })

  it('no longer points iOS users at a "More menu" that does not exist', () => {
    expect(text).not.toContain('More menu')
    expect(text).toContain('Account → Delete Account')
  })
})
