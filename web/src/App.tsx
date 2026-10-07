import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import {
  ArrowDown,
  ArrowUp,
  Check,
  ChevronRight,
  Circle,
  CircleAlert,
  CircleCheck,
  Download,
  Info,
  KeyRound,
  LogOut,
  Pencil,
  Plus,
  Smartphone,
  Trash2,
  X,
} from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { FieldSeparator } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { AppleLogo, GoogleLogo, PhonePreview } from '@/components/AuthArt'
import { SiteHeader } from '@/components/SiteHeader'
import { Splash } from '@/components/Splash'
import { StatusShell, StatusText } from '@/components/StatusShell'
import { cn } from '@/lib/utils'
import {
  accountExportFilename,
  buildAccountExport,
  serializeAccountExport,
  type AccountExportAgentKey,
  type AccountExportReminder,
} from './lib/accountExport'
import { nextSortOrder, sortReminders, swapSortOrders, temporarySortOrder, isAtCapacity, effectiveMaximum, POST_IT_HINT, DEFAULT_LOCK_SCREEN_MAX_LINES } from './lib/reminders'
import { AuthCallback } from './AuthCallback'
import { IosAuthHandoff } from './IosAuthHandoff'
import { Connect } from './Connect'
import { ConnectedAgents } from './ConnectedAgents'
import { LegalFooterLinks, PrivacyPage, SupportPage, TermsPage } from './LegalPages'
import {
  AGENT_TOKEN_PLACEHOLDER,
  LMR_AGENT_TOKEN_VAR,
  MCP_URL,
  authCallbackUrl,
  claudeMcpConfig,
  cursorMcpConfig,
  grokConnectorConfig,
  lmrAgentTokenHeaderTemplate,
  rememberReturnTo,
} from './mcp'
import { normalizePath, type AppRoute } from './routing'
import { supabase } from './supabase'
import { ThemeToggle } from './ThemeToggle'

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

type Reminder = {
  id: string
  user_id: string
  text: string
  sort_order: number
  is_done: boolean
  created_at: string
}

type ReminderChanges = Pick<Reminder, 'is_done' | 'sort_order' | 'text'>

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

function Board({ session, onNavigate }: { session: Session; onNavigate: (path: string) => void }) {
  const [reminders, setReminders] = useState<Reminder[]>([])
  const [text, setText] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editText, setEditText] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [adding, setAdding] = useState(false)
  const [reordering, setReordering] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const deleteButtonRef = useRef<HTMLButtonElement>(null)
  const [deletingAccount, setDeletingAccount] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [maxLines, setMaxLines] = useState(DEFAULT_LOCK_SCREEN_MAX_LINES)
  const loadSequence = useRef(0)
  const reorderingRef = useRef(false)

  useEffect(() => {
    if (!confirmDelete) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !deletingAccount) setConfirmDelete(false)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [confirmDelete, deletingAccount])

  const sorted = useMemo(() => sortReminders(reminders), [reminders])
  const active = useMemo(() => sorted.filter((item) => !item.is_done), [sorted])

  const load = useCallback(async () => {
    const sequence = ++loadSequence.current
    await supabase.rpc('delete_old_completed_reminders')
    if (sequence !== loadSequence.current) return

    const [{ data, error: fetchError }, prefsResult] = await Promise.all([
      supabase
        .from('reminders')
        .select('id, user_id, text, sort_order, is_done, created_at')
        .eq('user_id', session.user.id)
        .order('is_done')
        .order('sort_order')
        .order('created_at'),
      supabase
        .from('lock_screen_prefs')
        .select('max_lines')
        .eq('user_id', session.user.id)
        .maybeSingle(),
    ])
    if (sequence !== loadSequence.current) return
    if (fetchError) setError(fetchError.message)
    else setReminders(data ?? [])
    const synced = prefsResult.data?.max_lines
    if (typeof synced === 'number' && synced >= 1) setMaxLines(effectiveMaximum(synced))
    setLoading(false)
  }, [session.user.id])

  useEffect(() => {
    void load()
    let reloadTimer: number | undefined
    const channel = supabase
      .channel(`reminders:${session.user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'reminders', filter: `user_id=eq.${session.user.id}` },
        () => {
          if (reorderingRef.current) return
          window.clearTimeout(reloadTimer)
          reloadTimer = window.setTimeout(() => void load(), 100)
        },
      )
      .subscribe()
    return () => {
      window.clearTimeout(reloadTimer)
      void supabase.removeChannel(channel)
    }
  }, [load, session.user.id])

  async function add(event: FormEvent) {
    event.preventDefault()
    const value = text.trim()
    if (!value || adding) return
    if (isAtCapacity(active.length, maxLines)) {
      setError(POST_IT_HINT)
      return
    }
    setAdding(true)
    setText('')
    setError('')
    const nextOrder = nextSortOrder(reminders)
    const { error: insertError } = await supabase
      .from('reminders')
      .insert({ text: value, user_id: session.user.id, sort_order: nextOrder })
    if (insertError) {
      setText(value)
      setError(insertError.message)
    } else {
      await load()
    }
    setAdding(false)
  }

  async function patch(id: string, changes: Partial<ReminderChanges>) {
    setError('')
    setReminders((items) => items.map((item) => item.id === id ? { ...item, ...changes } : item))
    const { error: updateError } = await supabase
      .from('reminders')
      .update(changes)
      .eq('id', id)
      .eq('user_id', session.user.id)
    if (updateError) {
      setError(updateError.message)
      await load()
    }
  }

  async function remove(id: string) {
    setError('')
    setReminders((items) => items.filter((item) => item.id !== id))
    const { error: deleteError } = await supabase
      .from('reminders')
      .delete()
      .eq('id', id)
      .eq('user_id', session.user.id)
    if (deleteError) {
      setError(deleteError.message)
      await load()
    }
  }

  async function move(index: number, direction: -1 | 1) {
    if (reordering) return
    const target = index + direction
    if (target < 0 || target >= active.length) return
    const a = active[index]
    const b = active[target]
    setReordering(true)
    reorderingRef.current = true
    setError('')
    setReminders((items) => swapSortOrders(items, a.id, b.id))
    const temporaryOrder = temporarySortOrder(reminders)
    const updateOrder = (id: string, sortOrder: number) => supabase
      .from('reminders')
      .update({ sort_order: sortOrder })
      .eq('id', id)
      .eq('user_id', session.user.id)

    const { error: temporaryError } = await updateOrder(a.id, temporaryOrder)
    const { error: targetError } = temporaryError
      ? { error: temporaryError }
      : await updateOrder(b.id, a.sort_order)
    const { error: finalError } = temporaryError || targetError
      ? { error: temporaryError ?? targetError }
      : await updateOrder(a.id, b.sort_order)

    if (temporaryError || targetError || finalError) {
      if (!temporaryError) {
        if (!targetError) await updateOrder(b.id, b.sort_order)
        await updateOrder(a.id, a.sort_order)
      }
      setError((temporaryError ?? targetError ?? finalError)?.message ?? 'Could not reorder')
    }
    await load()
    setReordering(false)
    reorderingRef.current = false
  }

  async function saveEdit(id: string) {
    const value = editText.trim()
    if (value) await patch(id, { text: value })
    setEditingId(null)
  }

  const activeCount = reminders.filter((item) => !item.is_done).length
  const boardFull = isAtCapacity(activeCount, maxLines)

  async function signOut() {
    setError('')
    const { error: signOutError } = await supabase.auth.signOut()
    if (signOutError) setError(signOutError.message)
  }

  async function downloadMyData() {
    if (exporting) return
    setExporting(true)
    setError('')
    const [{ data: reminderRows, error: reminderError }, { data: prefs }, { data: keys, error: keyError }] =
      await Promise.all([
        supabase
          .from('reminders')
          .select('id, text, sort_order, is_done, created_at')
          .eq('user_id', session.user.id),
        supabase
          .from('lock_screen_prefs')
          .select('max_lines')
          .eq('user_id', session.user.id)
          .maybeSingle(),
        supabase
          .from('agent_token_clients')
          .select('id, name, created_at, last_used_at')
          .eq('user_id', session.user.id)
          .is('revoked_at', null),
      ])
    if (reminderError || keyError) {
      setError(reminderError?.message ?? keyError?.message ?? 'Could not export your data.')
      setExporting(false)
      return
    }
    const payload = buildAccountExport({
      email: session.user.email ?? null,
      userId: session.user.id,
      maxLines: typeof prefs?.max_lines === 'number' ? prefs.max_lines : maxLines,
      reminders: (reminderRows ?? []) as AccountExportReminder[],
      agentKeys: (keys ?? []) as AccountExportAgentKey[],
    })
    const blob = new Blob([serializeAccountExport(payload)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = accountExportFilename()
    link.click()
    URL.revokeObjectURL(url)
    setExporting(false)
  }

  async function deleteAccount() {
    setDeletingAccount(true)
    setError('')
    const { data, error: invokeError } = await supabase.functions.invoke('delete-account', {
      method: 'POST',
    })
    if (invokeError || data?.ok !== true) {
      setError(
        invokeError?.message
          ?? 'Could not delete your account. Stay signed in and try again, or email support from the Support page.',
      )
      setDeletingAccount(false)
      return
    }
    await supabase.auth.signOut()
    setConfirmDelete(false)
    setDeletingAccount(false)
  }

  return (
    <div className="board-shell mx-auto w-full max-w-2xl px-4 pb-12 sm:px-6">
      <a
        className="sr-only z-50 rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
        href="#board-main"
      >
        Skip to board
      </a>
      <SiteHeader onNavigate={onNavigate}>
        <ThemeToggle />
        <Button variant="ghost" size="icon-sm" type="button" aria-label="Sign out" title="Sign out" onClick={() => void signOut()}>
          <LogOut aria-hidden="true" />
        </Button>
      </SiteHeader>

      <main className="flex flex-col gap-10 pt-8 sm:pt-12">
        <section className="board flex flex-col gap-4" id="board-main" aria-labelledby="board-heading">
          <div className="space-y-1">
            <h1 id="board-heading" className="text-2xl font-semibold tracking-tight">Your board</h1>
            <p className="board-hint text-sm leading-relaxed text-muted-foreground" id="board-hint">{POST_IT_HINT}</p>
          </div>
          <form className="add-form flex gap-2" onSubmit={add}>
            <div className="relative flex-1">
              <Plus className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
              <Input
                className="pl-9"
                value={text}
                onChange={(event) => setText(event.target.value)}
                placeholder={boardFull ? 'Board full — combine lines instead' : "What shouldn't you forget?"}
                maxLength={500}
                disabled={boardFull || adding}
                aria-label="New reminder"
                aria-describedby="board-hint board-capacity"
              />
            </div>
            <Button type="submit" disabled={boardFull || !text.trim() || adding} aria-busy={adding || undefined}>
              {adding ? 'Adding…' : 'Add'}
            </Button>
          </form>
          <div className="board-meta flex justify-between gap-4 text-xs text-muted-foreground" id="board-capacity" aria-live="polite">
            <span>{activeCount}/{maxLines} {activeCount === 1 ? 'thing' : 'things'} on your mind</span>
            <span className="max-sm:hidden">Capacity set by your iPhone Lock Screen</span>
          </div>
          {error && (
            <Alert variant="destructive" className="pr-12">
              <CircleAlert aria-hidden="true" />
              <AlertDescription className="[overflow-wrap:anywhere]">{error}</AlertDescription>
              <Button
                variant="ghost"
                size="icon-sm"
                type="button"
                className="absolute top-1.5 right-1.5 text-current hover:text-current"
                aria-label="Dismiss error"
                onClick={() => setError('')}
              >
                <X aria-hidden="true" />
              </Button>
            </Alert>
          )}
          <div className="rounded-lg border">
            {loading ? (
              <div className="empty px-4 py-12 text-center text-sm text-muted-foreground" role="status">Loading your board…</div>
            ) : sorted.length === 0 ? (
              <div className="empty flex flex-col items-center gap-1 px-4 py-14 text-center">
                <Circle className="mb-2 size-5 text-muted-foreground" aria-hidden="true" />
                <h2 className="text-sm font-medium">Nothing to remember.</h2>
                <p className="text-sm text-muted-foreground">That's either excellent or suspicious.</p>
              </div>
            ) : (
              <ul className="reminder-list divide-y" aria-label="Reminders">
                {sorted.map((reminder) => {
                  const activeIndex = active.findIndex((item) => item.id === reminder.id)
                  return (
                    <li key={reminder.id} className="flex min-h-14 items-center gap-2 py-1.5 pr-1.5 pl-1.5">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="shrink-0 text-muted-foreground hover:text-foreground"
                        type="button"
                        aria-label={reminder.is_done ? `Mark "${reminder.text}" active` : `Complete "${reminder.text}"`}
                        aria-pressed={reminder.is_done}
                        title={reminder.is_done ? 'Mark active' : 'Complete'}
                        onClick={() => void patch(reminder.id, { is_done: !reminder.is_done })}
                      >
                        {reminder.is_done ? <CircleCheck aria-hidden="true" /> : <Circle aria-hidden="true" />}
                      </Button>
                      {editingId === reminder.id ? (
                        <form className="flex min-w-0 flex-1 items-center gap-1" onSubmit={(event) => { event.preventDefault(); void saveEdit(reminder.id) }}>
                          <Input
                            className="h-8"
                            value={editText}
                            onChange={(event) => setEditText(event.target.value)}
                            onKeyDown={(event) => { if (event.key === 'Escape') setEditingId(null) }}
                            maxLength={500}
                            aria-label={`Edit reminder: ${reminder.text}`}
                            autoFocus
                          />
                          <Button variant="ghost" size="icon" type="submit" aria-label="Save reminder" title="Save"><Check aria-hidden="true" /></Button>
                          <Button variant="ghost" size="icon" type="button" aria-label="Cancel editing" title="Cancel" onClick={() => setEditingId(null)}><X aria-hidden="true" /></Button>
                        </form>
                      ) : (
                        <span
                          className={cn(
                            'reminder-text min-w-0 flex-1 text-sm leading-relaxed [overflow-wrap:anywhere]',
                            reminder.is_done && 'text-muted-foreground line-through',
                          )}
                        >
                          {reminder.text}
                        </span>
                      )}
                      {editingId !== reminder.id && (
                        <div className="flex shrink-0 items-center text-muted-foreground">
                          {!reminder.is_done && <>
                            <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Move "${reminder.text}" up`} title="Move up" disabled={reordering || activeIndex === 0} onClick={() => void move(activeIndex, -1)}><ArrowUp aria-hidden="true" /></Button>
                            <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Move "${reminder.text}" down`} title="Move down" disabled={reordering || activeIndex === activeCount - 1} onClick={() => void move(activeIndex, 1)}><ArrowDown aria-hidden="true" /></Button>
                          </>}
                          <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Edit "${reminder.text}"`} title="Edit" onClick={() => { setEditingId(reminder.id); setEditText(reminder.text) }}><Pencil aria-hidden="true" /></Button>
                          <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Delete "${reminder.text}"`} title="Delete" onClick={() => void remove(reminder.id)}><Trash2 aria-hidden="true" /></Button>
                        </div>
                      )}
                    </li>
                  )
                })}
              </ul>
            )}
          </div>
        </section>

        <AgentAccess userId={session.user.id} accessToken={session.access_token} />

        <section className="flex flex-col gap-4" aria-labelledby="account-heading">
          <div className="space-y-1">
            <h2 id="account-heading" className="text-base font-semibold tracking-tight">Account</h2>
            <p className="account-email truncate text-sm text-muted-foreground">{session.user.email}</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              size="sm"
              type="button"
              disabled={exporting || deletingAccount}
              onClick={() => void downloadMyData()}
            >
              <Download aria-hidden="true" />
              {exporting ? 'Preparing…' : 'Download my data'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              type="button"
              className="text-destructive hover:text-destructive"
              ref={deleteButtonRef}
              disabled={deletingAccount}
              onClick={() => setConfirmDelete(true)}
            >
              <Trash2 aria-hidden="true" />
              Delete account
            </Button>
          </div>
        </section>
      </main>

      <footer className="board-footer mt-16 flex flex-col items-center gap-3 border-t pt-6 text-center text-xs text-muted-foreground">
        <p className="flex items-center gap-2"><Smartphone className="size-3.5" aria-hidden="true" /> Open the app once after signing in to add the lock-screen widget.</p>
        <LegalFooterLinks onNavigate={onNavigate} />
      </footer>

      <AlertDialog
        open={confirmDelete}
        onOpenChange={(open) => { if (!open && !deletingAccount) setConfirmDelete(false) }}
      >
        <AlertDialogContent
          className="delete-dialog sm:max-w-md"
          overlayProps={{ onClick: () => { if (!deletingAccount) setConfirmDelete(false) } }}
          onCloseAutoFocus={(event) => {
            // The dialog is opened from state, not a Radix Trigger, so return focus by hand.
            event.preventDefault()
            deleteButtonRef.current?.focus()
          }}
        >
          <AlertDialogHeader>
            <AlertDialogTitle>Delete your account?</AlertDialogTitle>
            <AlertDialogDescription>
              This permanently removes your reminders, device registrations, lock-screen prefs,
              agent access, and sign-in. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deletingAccount}>Cancel</AlertDialogCancel>
            <Button
              variant="destructive"
              type="button"
              disabled={deletingAccount}
              onClick={() => void deleteAccount()}
            >
              {deletingAccount ? 'Deleting…' : 'Delete forever'}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}

type AgentTokenClient = {
  id: string
  name: string
  created_at: string
  last_used_at: string | null
  revoked_at: string | null
}

function AgentAccess({ userId, accessToken }: { userId: string; accessToken: string }) {
  const [tokens, setTokens] = useState<AgentTokenClient[]>([])
  const [name, setName] = useState('')
  const [minted, setMinted] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const { data, error: fetchError } = await supabase
      .from('agent_token_clients')
      .select('id, name, created_at, last_used_at, revoked_at')
      .eq('user_id', userId)
      .is('revoked_at', null)
      .order('created_at', { ascending: false })
    if (fetchError) setError(fetchError.message)
    else setTokens(data ?? [])
  }, [userId])

  useEffect(() => { void load() }, [load])

  async function mint(event: FormEvent) {
    event.preventDefault()
    const trimmed = name.trim()
    if (!trimmed || busy) return
    setBusy(true)
    setError('')
    const { data, error: rpcError } = await supabase.rpc('mint_agent_token', { p_name: trimmed })
    setBusy(false)
    if (rpcError || typeof data !== 'string') {
      setError(rpcError?.message ?? 'Could not create key')
      return
    }
    setName('')
    setMinted(data)
    await load()
  }

  async function revoke(id: string) {
    if (busy) return
    setBusy(true)
    setError('')
    const { error: rpcError } = await supabase.rpc('revoke_agent_token', { p_id: id })
    setBusy(false)
    if (rpcError) setError(rpcError.message)
    else await load()
  }

  const code = 'rounded bg-muted px-1 py-0.5 font-mono text-[0.8125em] text-foreground'
  const pre = 'overflow-x-auto rounded-md border bg-muted/50 p-3 font-mono text-xs leading-relaxed text-foreground'
  return (
    <section className="agent-access flex flex-col gap-4" aria-labelledby="agent-access-heading">
      <h2 id="agent-access-heading" className="text-base font-semibold tracking-tight">Agent access</h2>
      <ConnectedAgents accessToken={accessToken} />
      <div className="space-y-3 text-sm leading-relaxed text-muted-foreground">
        <p>
          Grok, Cursor, Claude, and Codex can finish <code className={code}>/connect</code>. Add the plugin or paste
          {' '}<span className="[overflow-wrap:anywhere] text-foreground">{MCP_URL}</span>, then sign in when asked. That is the usual path. No tokens to copy.
        </p>
        <p>
          For hosts that cannot use OAuth, mint a key under Advanced, then set
          {' '}<code className={cn(code, '[overflow-wrap:anywhere]')}>Authorization: Bearer {AGENT_TOKEN_PLACEHOLDER}</code>
          {' '}(or plugin variable <code className={code}>{LMR_AGENT_TOKEN_VAR}</code>).
        </p>
      </div>
      <details className="agent-snippets group rounded-lg border text-sm">
        <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-3 font-medium select-none [&::-webkit-details-marker]:hidden">
          <ChevronRight className="size-4 text-muted-foreground transition-transform group-open:rotate-90" aria-hidden="true" />
          Advanced: personal keys
        </summary>
        <div className="flex flex-col gap-4 border-t px-4 py-4 text-muted-foreground">
          <p className="leading-relaxed">
            Mint a key below, then paste it once into the header or <code className={code}>{LMR_AGENT_TOKEN_VAR}</code>.
            Shown once. Revoke anytime.
          </p>
          <form className="agent-key-form flex gap-2 max-sm:flex-col" onSubmit={mint}>
            <Label className="sr-only" htmlFor="agent-key-name">Key name</Label>
            <Input
              id="agent-key-name"
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="Cursor, Codex, Grok Bot…"
              maxLength={64}
              autoComplete="off"
            />
            <Button type="submit" disabled={busy || !name.trim()}>
              {busy ? 'Creating…' : 'Create key'}
            </Button>
          </form>
          {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
          {minted && (
            <Alert role="status" className="minted-key">
              <KeyRound aria-hidden="true" />
              <AlertDescription className="w-full gap-2 text-foreground">
                <p>Copy this now. It will not be shown again.</p>
                <Input readOnly className="font-mono text-xs" value={minted} onFocus={(event) => event.currentTarget.select()} aria-label="New agent token" />
                <Button variant="outline" size="sm" type="button" onClick={() => setMinted(null)}>I saved it</Button>
              </AlertDescription>
            </Alert>
          )}
          {tokens.length > 0 && (
            <ul className="agent-token-list divide-y rounded-md border" aria-label="Active agent keys">
              {tokens.map((token) => (
                <li key={token.id} className="flex items-center justify-between gap-4 px-3 py-2.5">
                  <div className="grid min-w-0 gap-0.5">
                    <strong className="truncate text-sm font-medium text-foreground">{token.name}</strong>
                    <span className="text-xs">Created {new Date(token.created_at).toLocaleString()}</span>
                    {token.last_used_at && <span className="text-xs">Last used {new Date(token.last_used_at).toLocaleString()}</span>}
                  </div>
                  <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" type="button" disabled={busy} onClick={() => void revoke(token.id)}>
                    Revoke
                  </Button>
                </li>
              ))}
            </ul>
          )}
          <div className="grid gap-2">
            <p>Cursor <code className={code}>~/.cursor/mcp.json</code></p>
            <pre className={pre}>{cursorMcpConfig(MCP_URL)}</pre>
          </div>
          <div className="grid gap-2">
            <p>Claude Code / Codex <code className={code}>.mcp.json</code></p>
            <pre className={pre}>{claudeMcpConfig(MCP_URL)}</pre>
          </div>
          <div className="grid gap-2">
            <p>Grok Bot: Settings → Plugins → custom connector. Add the URL and sign in when prompted.</p>
            <pre className={pre}>{grokConnectorConfig(MCP_URL)}</pre>
          </div>
          <p className="leading-relaxed">
            Plugin hosts can set <code className={code}>{LMR_AGENT_TOKEN_VAR}</code> instead of pasting the header:
            {' '}<code className={cn(code, '[overflow-wrap:anywhere]')}>{lmrAgentTokenHeaderTemplate()}</code>
          </p>
        </div>
      </details>
    </section>
  )
}

export default function App() {
  const [path, navigate] = usePathname()
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(false)
  const [authError, setAuthError] = useState('')

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
      ? <Connect session={session} onNavigate={navigate} />
      : <SignIn onNavigate={navigate} connectingAgent />
  }

  return session
    ? <Board session={session} onNavigate={navigate} />
    : <SignIn onNavigate={navigate} />
}
