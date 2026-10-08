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

  it('shows the 8 October 2026 revision date', () => {
    expect(text).toContain('Last updated: 8 October 2026')
  })

  it('names the canonical domain and the retired one', () => {
    expect(text).toContain('https://lmr.sillyapps.co')
    expect(text).toMatch(/lmr\.edmundlim\.systems, redirects here/)
  })

  it('says deletion revokes Sign in with Apple tokens and connected-agent grants', () => {
    expect(text).toContain('revokes every connected-agent grant')
    expect(text).toContain('Sign in with Apple tokens')
  })

  it('discloses opt-in TestFlight feedback and crash data from Apple', () => {
    expect(text).toContain('TestFlight feedback and crash data.')
    expect(text).toMatch(/only if you choose to send them or opt in/)
  })

  it('no longer points iOS users at a "More menu" that does not exist', () => {
    expect(text).not.toContain('More menu')
    expect(text).toContain('Account → Delete Account')
  })
})
