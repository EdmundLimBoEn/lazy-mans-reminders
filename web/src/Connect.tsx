import { FormEvent, useEffect, useMemo, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { LegalFooterLinks } from './LegalPages'
import { MCP_ORIGIN } from './mcp'
import { consentCanApprove, parseConsentSummary, permissionSentence, type ConsentSummary } from './consentSummary'
import { bindFailureMessage, isSafeOauthRedirect } from './oauthConnect'

function SameWindowNote() {
  return (
    <p className="connect-hint" role="status">
      Finish sign-in in the browser that opened, then tap Allow.
    </p>
  )
}

export function Connect({ session, onNavigate }: { session: Session; onNavigate: (path: string) => void }) {
  const state = useMemo(() => new URLSearchParams(window.location.search).get('state') ?? '', [])
  const [summary, setSummary] = useState<ConsentSummary | null>(null)
  const [phase, setPhase] = useState<'loading' | 'ready' | 'blocked'>('loading')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!state) return
    let cancelled = false
    setPhase('loading')
    setSummary(null)
    setError('')
    void (async () => {
      try {
        const response = await fetch(`${MCP_ORIGIN}/consent?state=${encodeURIComponent(state)}`, {
          headers: { Authorization: `Bearer ${session.access_token}` },
        })
        const body = await response.json().catch(() => null) as { error?: string } | null
        if (cancelled) return
        const parsed = parseConsentSummary(body)
        if (!response.ok || !consentCanApprove(parsed)) {
          setSummary(parsed)
          setPhase('blocked')
          setError(bindFailureMessage(body?.error))
          return
        }
        setSummary(parsed)
        setPhase('ready')
      } catch {
        if (!cancelled) {
          setPhase('blocked')
          setError('Could not reach the agent connector. Stay on this page and try again.')
        }
      }
    })()
    return () => { cancelled = true }
  }, [state, session.access_token])

  async function allow(event: FormEvent) {
    event.preventDefault()
    if (!state || busy || phase !== 'ready' || !consentCanApprove(summary)) return
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
        setError(bindFailureMessage(body.error))
        return
      }
      if (!isSafeOauthRedirect(body.redirectTo)) {
        setError('The agent sent an unsafe return address. Ask it to connect again.')
        return
      }
      window.location.replace(body.redirectTo)
    } catch {
      setError('Could not reach the agent connector. Stay on this page and try Allow again.')
    } finally {
      setBusy(false)
    }
  }

  async function deny() {
    if (!state || busy) return
    setBusy(true)
    setError('')
    try {
      const response = await fetch(`${MCP_ORIGIN}/consent/deny`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ state }),
      })
      const body = await response.json().catch(() => ({})) as { redirectTo?: string | null; error?: string }
      if (!response.ok) {
        setError(bindFailureMessage(body.error))
        return
      }
      if (body.redirectTo && isSafeOauthRedirect(body.redirectTo)) {
        window.location.replace(body.redirectTo)
        return
      }
      window.location.assign('/')
    } catch {
      setError('Could not reach the agent connector. Stay on this page and try Deny again.')
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

  const canAllow = phase === 'ready' && consentCanApprove(summary) && !busy
  const agentName = summary?.client.name ?? 'Unnamed agent'

  return (
    <main className="auth-shell">
      <section className="auth-panel connect-panel">
        <div className="auth-card">
          <h2>Let this agent use your board?</h2>
          <p>Signed in as {session.user.email ?? 'your account'}.</p>
          {phase === 'loading' && <p role="status">Checking which agent asked…</p>}
          {summary && (
            <dl className="consent-facts">
              <div>
                <dt>Agent</dt>
                <dd>{agentName}</dd>
              </div>
              <div>
                <dt>Returns to</dt>
                <dd>{summary.redirectOrigin}</dd>
              </div>
              <div>
                <dt>Access</dt>
                <dd>{permissionSentence(summary.permissions)}</dd>
              </div>
            </dl>
          )}
          <p>
            The agent name is whatever that client typed at registration. Check the return address
            before you allow. You can revoke it later from the board, or it ends when you delete
            your account.
          </p>
          <SameWindowNote />
          {error && <p className="error" role="alert">{error}</p>}
          <form className="connect-actions" onSubmit={allow}>
            <button className="primary" type="submit" disabled={!canAllow}>
              {busy ? 'Connecting…' : 'Allow'}
            </button>
            <button className="text-button" type="button" disabled={busy} onClick={() => void deny()}>
              Deny
            </button>
          </form>
          <LegalFooterLinks onNavigate={onNavigate} />
        </div>
      </section>
    </main>
  )
}
