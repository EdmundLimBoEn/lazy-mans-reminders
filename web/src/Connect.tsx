import { FormEvent, type ReactNode, useEffect, useMemo, useState } from 'react'
import { Info } from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { SiteHeader } from '@/components/SiteHeader'
import type { Session } from '@supabase/supabase-js'
import { LegalFooterLinks } from './LegalPages'
import { MCP_ORIGIN } from './mcp'
import { consentCanApprove, parseConsentSummary, permissionSentence, type ConsentSummary } from './consentSummary'
import { bindFailureMessage, isSafeOauthRedirect } from './oauthConnect'
import { ThemeToggle } from './ThemeToggle'

function SameWindowNote() {
  return (
    <Alert role="status">
      <Info aria-hidden="true" />
      <AlertDescription>Finish sign-in in the browser that opened, then tap Allow.</AlertDescription>
    </Alert>
  )
}

function ConnectShell({ onNavigate, children }: { onNavigate: (path: string) => void; children: ReactNode }) {
  return (
    <div className="mx-auto flex min-h-svh w-full max-w-5xl flex-col px-4 sm:px-6">
      <SiteHeader onNavigate={onNavigate}>
        <ThemeToggle />
      </SiteHeader>
      <main className="auth-shell flex flex-1 flex-col items-center justify-center gap-6 py-12">
        {children}
        <LegalFooterLinks onNavigate={onNavigate} />
      </main>
    </div>
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
      <ConnectShell onNavigate={onNavigate}>
        <Card className="auth-card w-full max-w-md">
          <CardHeader>
            <CardTitle><h2 className="text-lg font-semibold tracking-tight">Nothing to connect</h2></CardTitle>
            <CardDescription className="leading-relaxed">Open this page from Grok, Claude, Cursor, or Codex when they ask to use your board.</CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild className="w-full"><a href="/">Back to the board</a></Button>
          </CardContent>
        </Card>
      </ConnectShell>
    )
  }

  const canAllow = phase === 'ready' && consentCanApprove(summary) && !busy
  const agentName = summary?.client.name ?? 'Unnamed agent'

  return (
    <ConnectShell onNavigate={onNavigate}>
      <Card className="auth-card w-full max-w-md">
        <CardHeader>
          <CardTitle><h2 className="text-lg font-semibold tracking-tight">Let this agent use your board?</h2></CardTitle>
          <CardDescription className="[overflow-wrap:anywhere]">Signed in as {session.user.email ?? 'your account'}.</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4 text-sm">
          {phase === 'loading' && <p className="text-muted-foreground" role="status">Checking which agent asked…</p>}
          {summary && (
            <dl className="consent-facts divide-y rounded-lg border">
              <div className="grid gap-1 px-3 py-2.5 sm:grid-cols-[6rem_1fr] sm:gap-3">
                <dt className="text-muted-foreground">Agent</dt>
                <dd className="font-medium [overflow-wrap:anywhere]">{agentName}</dd>
              </div>
              <div className="grid gap-1 px-3 py-2.5 sm:grid-cols-[6rem_1fr] sm:gap-3">
                <dt className="text-muted-foreground">Returns to</dt>
                <dd className="font-medium [overflow-wrap:anywhere]">{summary.redirectOrigin}</dd>
              </div>
              <div className="grid gap-1 px-3 py-2.5 sm:grid-cols-[6rem_1fr] sm:gap-3">
                <dt className="text-muted-foreground">Access</dt>
                <dd className="[overflow-wrap:anywhere]">{permissionSentence(summary.permissions)}</dd>
              </div>
            </dl>
          )}
          <p className="leading-relaxed text-muted-foreground">
            The agent name is whatever that client typed at registration. Check the return address
            before you allow. You can revoke it later from the board, or it ends when you delete
            your account.
          </p>
          <SameWindowNote />
          {error && <p className="text-destructive" role="alert">{error}</p>}
          <form className="connect-actions grid gap-2" onSubmit={allow}>
            <Button type="submit" disabled={!canAllow}>
              {busy ? 'Connecting…' : 'Allow'}
            </Button>
            <Button variant="ghost" type="button" disabled={busy} onClick={() => void deny()}>
              Deny
            </Button>
          </form>
        </CardContent>
      </Card>
    </ConnectShell>
  )
}
