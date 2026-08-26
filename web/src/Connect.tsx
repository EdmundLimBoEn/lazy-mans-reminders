import { FormEvent, useMemo, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { LegalFooterLinks } from './LegalPages'
import { MCP_ORIGIN } from './mcp'

export function Connect({ session, onNavigate }: { session: Session; onNavigate: (path: string) => void }) {
  const state = useMemo(() => new URLSearchParams(window.location.search).get('state') ?? '', [])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function allow(event: FormEvent) {
    event.preventDefault()
    if (!state || busy) return
    setBusy(true)
    setError('')
    try {
      const response = await fetch(`${MCP_ORIGIN}/bind`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ state }),
      })
      const body = await response.json().catch(() => ({})) as { redirectTo?: string; error?: string }
      if (!response.ok || !body.redirectTo) {
        setError(body.error === 'expired_state'
          ? 'This link expired. Ask the agent to connect again.'
          : 'Could not connect the agent. Try signing in again.')
        return
      }
      window.location.assign(body.redirectTo)
    } catch {
      setError('Could not connect the agent. Try signing in again.')
    } finally {
      setBusy(false)
    }
  }

  if (!state) {
    return (
      <main className="auth-shell">
        <section className="auth-panel connect-panel">
          <div className="auth-card">
            <h2>Nothing to connect</h2>
            <p>Open this page from Grok, Claude, Cursor, or Codex when they ask to use your board.</p>
            <a className="primary" href="/">Back to the board</a>
            <LegalFooterLinks onNavigate={onNavigate} />
          </div>
        </section>
      </main>
    )
  }

  return (
    <main className="auth-shell">
      <section className="auth-panel connect-panel">
        <div className="auth-card">
          <h2>Let this agent use your board?</h2>
          <p>
            Signed in as {session.user.email ?? 'your account'}. Allow once and the agent can read,
            add, and complete reminders until you sign it out or delete your account. See Privacy
            for what is shared.
          </p>
          {error && <p className="error" role="alert">{error}</p>}
          <form className="connect-actions" onSubmit={allow}>
            <button className="primary" type="submit" disabled={busy}>
              {busy ? 'Connecting…' : 'Allow'}
            </button>
            <a className="text-button" href="/">Deny</a>
          </form>
          <LegalFooterLinks onNavigate={onNavigate} />
        </div>
      </section>
    </main>
  )
}
