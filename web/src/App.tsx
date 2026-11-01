import { lazy, Suspense, FormEvent, useCallback, useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { Info } from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { FieldSeparator } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { AppleLogo, GoogleLogo, PhonePreview } from '@/components/AuthArt'
import { SiteHeader } from '@/components/SiteHeader'
import { Splash } from '@/components/Splash'
import { StatusShell, StatusText } from '@/components/StatusShell'
import { AuthCallback } from './AuthCallback'
import { IosAuthHandoff } from './IosAuthHandoff'
import { Connect } from './Connect'
import { LegalFooterLinks, PrivacyPage, SupportPage, TermsPage } from './LegalPages'
import { authCallbackUrl, rememberReturnTo } from './mcp'
import { normalizePath, type AppRoute } from './routing'
import { supabase } from './supabase'
import { ThemeToggle } from './ThemeToggle'

const Board = lazy(() => import('./Board'))

function usePathname(): [AppRoute, (path: string) => void] {
  const [path, setPath] = useState<AppRoute>(() => normalizePath(window.location.pathname))

  useEffect(() => {
    const onPopState = () => setPath(normalizePath(window.location.pathname))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [])

  const navigate = useCallback((next: string) => {
    const normalized = normalizePath(next)
    if (normalized !== normalizePath(window.location.pathname)) {
      window.history.pushState({}, '', normalized)
    }
    setPath(normalized)
    window.scrollTo(0, 0)
  }, [])

  return [path, navigate]
}

function SignIn({
  onNavigate,
  connectingAgent = false,
}: {
  onNavigate: (path: string) => void
  connectingAgent?: boolean
}) {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [loading, setLoading] = useState(false)
  const [oauthLoading, setOauthLoading] = useState<'apple' | 'google' | null>(null)
  const [error, setError] = useState('')

  async function submit(event: FormEvent) {
    event.preventDefault()
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail) return
    setLoading(true)
    setError('')
    rememberReturnTo()
    const { error: authError } = await supabase.auth.signInWithOtp({
      email: normalizedEmail,
      options: { emailRedirectTo: authCallbackUrl() },
    })
    setLoading(false)
    if (authError) setError(authError.message)
    else {
      setEmail(normalizedEmail)
      setSent(true)
    }
  }

  async function signInWithProvider(provider: 'apple' | 'google') {
    setOauthLoading(provider)
    setError('')
    rememberReturnTo()
    const { error: authError } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: authCallbackUrl(),
        queryParams: provider === 'google'
          ? { prompt: 'select_account', access_type: 'online' }
          : undefined,
        scopes: provider === 'apple' ? 'name email' : undefined,
      },
    })
    if (authError) {
      setError(authError.message)
      setOauthLoading(null)
    }
  }

  const busy = loading || oauthLoading !== null

  return (
    <div className="mx-auto flex min-h-svh w-full max-w-6xl flex-col px-4 sm:px-6">
      <SiteHeader onNavigate={onNavigate}>
        <ThemeToggle />
      </SiteHeader>
      <main className="auth-shell grid flex-1 content-center gap-10 py-10 lg:grid-cols-[1fr_minmax(0,24rem)] lg:gap-20 lg:py-16">
        <section className="auth-copy flex flex-col gap-10">
          <div className="space-y-4">
            <h1 className="text-3xl font-medium tracking-tight text-balance sm:text-4xl">
              Write it once.<br />See it all day.
            </h1>
            <p className="max-w-md text-base leading-relaxed text-muted-foreground">
              A tiny reminder board that lives on your iPhone lock screen.
              Nothing to organise. Nothing to forget.
            </p>
          </div>
          <PhonePreview />
        </section>
        <section className="auth-panel flex flex-col gap-6">
          <Card className="auth-card gap-5">
            <CardHeader>
              <CardTitle>
                <h2 className="text-lg font-semibold tracking-tight">
                  {sent ? 'Check your inbox' : connectingAgent ? 'Sign in to connect this agent' : 'Your board, everywhere'}
                </h2>
              </CardTitle>
              <CardDescription aria-live="polite" className="leading-relaxed">
                {sent
                  ? `We sent a secure sign-in link to ${email}. Open it in this same browser window.`
                  : connectingAgent
                    ? 'Sign in with Apple or Google in this same window, then tap Allow. Email links often open in another app and fail this step.'
                    : 'Sign in with Apple, Google, or email. No password to remember.'}
              </CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
              {connectingAgent && !sent && (
                <Alert role="status">
                  <Info aria-hidden="true" />
                  <AlertDescription>
                    Finish sign-in in the browser that opened. You will return here to tap Allow.
                  </AlertDescription>
                </Alert>
              )}
              {!sent && (
                <>
                  <div className="grid gap-2">
                    <Button
                      variant="outline"
                      className="w-full"
                      type="button"
                      disabled={busy}
                      aria-busy={oauthLoading === 'apple' || undefined}
                      onClick={() => void signInWithProvider('apple')}
                    >
                      <AppleLogo />
                      {oauthLoading === 'apple' ? 'Redirecting…' : 'Continue with Apple'}
                    </Button>
                    <Button
                      variant="outline"
                      className="w-full"
                      type="button"
                      disabled={busy}
                      aria-busy={oauthLoading === 'google' || undefined}
                      onClick={() => void signInWithProvider('google')}
                    >
                      <GoogleLogo />
                      {oauthLoading === 'google' ? 'Redirecting…' : 'Continue with Google'}
                    </Button>
                  </div>
                  <FieldSeparator
                    role="separator"
                    aria-label="or"
                    className="my-0 text-xs uppercase *:data-[slot=field-separator-content]:bg-card"
                  >
                    or email
                  </FieldSeparator>
                  <form onSubmit={submit} className="grid gap-3">
                    <div className="grid gap-2">
                      <Label htmlFor="email">Email address</Label>
                      <Input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(event) => setEmail(event.target.value)}
                        placeholder="you@example.com"
                        autoComplete="email"
                        required
                      />
                    </div>
                    {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
                    <Button className="w-full" type="submit" disabled={busy}>
                      {loading ? 'Sending…' : 'Send sign-in link'}
                    </Button>
                  </form>
                </>
              )}
              {sent && (
                <>
                  {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
                  <Button variant="outline" className="w-full" type="button" onClick={() => setSent(false)}>
                    Use another email
                  </Button>
                </>
              )}
            </CardContent>
          </Card>
          <LegalFooterLinks onNavigate={onNavigate} />
        </section>
      </main>
    </div>
  )
}

export default function App() {
  const [path, navigate] = usePathname()
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(false)
  const [authError, setAuthError] = useState('')
  const [manualAppleRevocation, setManualAppleRevocation] = useState(false)

  useEffect(() => {
    const titles: Record<AppRoute, string> = {
      '/': "Lazy Man's Reminders",
      '/privacy': "Privacy · Lazy Man's Reminders",
      '/terms': "Terms · Lazy Man's Reminders",
      '/support': "Support · Lazy Man's Reminders",
      '/auth/callback': "Signing in · Lazy Man's Reminders",
      '/auth/ios': "Open the app · Lazy Man's Reminders",
      '/connect': "Connect an agent · Lazy Man's Reminders",
      'not-found': "Not found · Lazy Man's Reminders",
    }
    document.title = titles[path]
  }, [path])

  useEffect(() => {
    void supabase.auth.getSession().then(({ data, error }) => {
      if (error) setAuthError(error.message)
      setSession(data.session)
      setReady(true)
    })
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setAuthError('')
      setSession(nextSession)
      setReady(true)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  if (path === '/auth/callback') return <AuthCallback onNavigate={navigate} />
  if (path === '/auth/ios') return <IosAuthHandoff onNavigate={navigate} />
  if (path === '/privacy') return <PrivacyPage onNavigate={navigate} />
  if (path === '/terms') return <TermsPage onNavigate={navigate} />
  if (path === '/support') return <SupportPage onNavigate={navigate} />
  if (path === 'not-found') {
    return (
      <StatusShell title="Page not found" onNavigate={navigate}>
        <StatusText>That URL is not part of Lazy Man's Reminders.</StatusText>
        <Button asChild className="mt-3">
          <a href="/" onClick={(event) => { event.preventDefault(); navigate('/') }}>Back to the board</a>
        </Button>
      </StatusShell>
    )
  }

  if (!ready) return <Splash label="Loading" />
  if (authError) {
    return (
      <StatusShell title="Could not start the app" role="alert" onNavigate={navigate}>
        <StatusText>{authError}</StatusText>
        <Button className="mt-3" type="button" onClick={() => window.location.reload()}>Try again</Button>
      </StatusShell>
    )
  }
  if (path === '/connect') {
    return session
      ? <Connect key={session.user.id} session={session} onNavigate={navigate} />
      : <SignIn onNavigate={navigate} connectingAgent />
  }

  return (
    <>
      {manualAppleRevocation && (
        <Alert role="status" className="mx-auto my-4 w-[calc(100%-2rem)] max-w-2xl">
          <Info aria-hidden="true" />
          <AlertDescription>
            <p>Your account and reminder data were deleted. Apple access could not be revoked automatically.</p>
            <a className="underline" href="https://support.apple.com/102571" target="_blank" rel="noreferrer">
              Follow Apple’s instructions to stop using Sign in with Apple for Lazy Man’s Reminders.
            </a>
          </AlertDescription>
        </Alert>
      )}
      {session
        ? (
          <Suspense fallback={<Splash label="Loading" />}>
            <Board key={session.user.id} session={session} onNavigate={navigate} onAccountDeleted={setManualAppleRevocation} />
          </Suspense>
        )
        : <SignIn onNavigate={navigate} />}
    </>
  )
}
