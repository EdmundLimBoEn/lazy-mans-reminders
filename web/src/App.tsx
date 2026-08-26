import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import {
  ArrowDown,
  ArrowUp,
  Check,
  Circle,
  LogOut,
  Pencil,
  Plus,
  Smartphone,
  Trash2,
  X,
} from 'lucide-react'
import { nextSortOrder, sortReminders, swapSortOrders, temporarySortOrder, isAtCapacity, POST_IT_HINT, DEFAULT_LOCK_SCREEN_MAX_LINES } from './lib/reminders'
import { AuthCallback } from './AuthCallback'
import { Connect } from './Connect'
import { LegalFooterLinks, PrivacyPage, SupportPage, TermsPage } from './LegalPages'
import { authCallbackUrl, MCP_URL, rememberReturnTo } from './mcp'
import { normalizePath, type AppRoute } from './routing'
import { supabase } from './supabase'

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

function SignIn({ onNavigate }: { onNavigate: (path: string) => void }) {
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
    <main className="auth-shell">
      <section className="auth-copy">
        <div className="brand-mark">LM</div>
        <p className="eyebrow">Lazy Man's Reminders</p>
        <h1>Write it once.<br />See it all day.</h1>
        <p className="lede">
          A tiny reminder board that lives on your iPhone lock screen.
          Nothing to organise. Nothing to forget.
        </p>
        <div className="phone-preview" aria-hidden="true">
          <div className="dynamic-island" />
          <p className="preview-time">9:41</p>
          <div className="widget-preview">
            <span>REMINDERS</span>
            <p>□ Book dentist</p>
            <p>□ Send the invoice</p>
          </div>
        </div>
      </section>
      <section className="auth-panel">
        <div className="auth-card">
          <Smartphone size={24} aria-hidden="true" />
          <h2>{sent ? 'Check your inbox' : 'Your board, everywhere'}</h2>
          <p aria-live="polite">
            {sent
              ? `We sent a secure sign-in link to ${email}.`
              : 'Sign in with Apple, Google, or email. No password to remember.'}
          </p>
          {!sent && (
            <>
              <div className="oauth-stack">
                <button
                  className="oauth-button oauth-apple"
                  type="button"
                  disabled={busy}
                  aria-busy={oauthLoading === 'apple' || undefined}
                  onClick={() => void signInWithProvider('apple')}
                >
                  {oauthLoading === 'apple' ? 'Redirecting…' : 'Continue with Apple'}
                </button>
                <button
                  className="oauth-button oauth-google"
                  type="button"
                  disabled={busy}
                  aria-busy={oauthLoading === 'google' || undefined}
                  onClick={() => void signInWithProvider('google')}
                >
                  {oauthLoading === 'google' ? 'Redirecting…' : 'Continue with Google'}
                </button>
              </div>
              <div className="auth-divider" role="separator" aria-label="or">
                <span>or email</span>
              </div>
              <form onSubmit={submit}>
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="you@example.com"
                  autoComplete="email"
                  required
                />
                {error && <p className="error" role="alert">{error}</p>}
                <button className="primary" type="submit" disabled={busy}>
                  {loading ? 'Sending…' : 'Send sign-in link'}
                </button>
              </form>
            </>
          )}
          {sent && (
            <>
              {error && <p className="error" role="alert">{error}</p>}
              <button className="text-button" type="button" onClick={() => setSent(false)}>Use another email</button>
            </>
          )}
          <LegalFooterLinks onNavigate={onNavigate} />
        </div>
      </section>
    </main>
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
  const [deletingAccount, setDeletingAccount] = useState(false)
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
    if (typeof synced === 'number' && synced >= 1) setMaxLines(synced)
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

  async function deleteAccount() {
    setDeletingAccount(true)
    setError('')
    const { data, error: invokeError } = await supabase.functions.invoke('delete-account', {
      method: 'POST',
    })
    if (invokeError || data?.ok !== true) {
      const [{ error: remindersError }, { error: tokensError }, { error: agentKeysError }] = await Promise.all([
        supabase.from('reminders').delete().eq('user_id', session.user.id),
        supabase.from('device_tokens').delete().eq('user_id', session.user.id),
        supabase.from('agent_tokens').delete().eq('user_id', session.user.id),
      ])
      if (remindersError || tokensError || agentKeysError) {
        setError(
          remindersError?.message
          ?? tokensError?.message
          ?? agentKeysError?.message
          ?? invokeError?.message
          ?? 'Could not delete account. Visit Support for help.',
        )
        setDeletingAccount(false)
        return
      }
      await supabase.auth.signOut()
      setConfirmDelete(false)
      setDeletingAccount(false)
      window.alert(
        'Your reminders were deleted and you have been signed out. '
        + 'To finish removing your sign-in account, email support via the Support page.',
      )
      return
    }
    await supabase.auth.signOut()
    setConfirmDelete(false)
    setDeletingAccount(false)
  }

  return (
    <main className="board-shell">
      <a className="skip-link" href="#board-main">Skip to board</a>
      <header>
        <div>
          <p className="eyebrow">Lazy Man's Reminders</p>
          <h1 id="board-heading">Your board</h1>
        </div>
        <div className="account">
          <div className="account-meta">
            <span>{session.user.email}</span>
            <button
              className="text-button danger-text"
              type="button"
              disabled={deletingAccount}
              onClick={() => setConfirmDelete(true)}
            >
              Delete account
            </button>
          </div>
          <button className="icon-button" type="button" aria-label="Sign out" title="Sign out" onClick={() => void signOut()}>
            <LogOut size={18} aria-hidden="true" />
          </button>
        </div>
      </header>

      <section className="board" id="board-main" aria-labelledby="board-heading">
        <form className="add-form" onSubmit={add}>
          <Plus size={22} aria-hidden="true" />
          <input
            value={text}
            onChange={(event) => setText(event.target.value)}
            placeholder={boardFull ? 'Board full — combine lines instead' : "What shouldn't you forget?"}
            maxLength={500}
            autoFocus
            disabled={boardFull || adding}
            aria-label="New reminder"
            aria-describedby="board-hint board-capacity"
            aria-invalid={boardFull ? true : undefined}
          />
          <button className="primary" type="submit" disabled={boardFull || !text.trim() || adding} aria-busy={adding || undefined}>
            {adding ? 'Adding…' : 'Add'}
          </button>
        </form>
        <div className="board-meta" id="board-capacity" aria-live="polite">
          <span>{activeCount}/{maxLines} {activeCount === 1 ? 'thing' : 'things'} on your mind</span>
          <span>Capacity set by your iPhone Lock Screen</span>
        </div>
        <p className="board-hint" id="board-hint">{POST_IT_HINT}</p>
        {error && (
          <div className="error-banner" role="alert">
            <span>{error}</span>
            <button type="button" aria-label="Dismiss error" onClick={() => setError('')}><X size={16} aria-hidden="true" /></button>
          </div>
        )}
        {loading ? (
          <div className="empty" role="status">Loading your board…</div>
        ) : sorted.length === 0 ? (
          <div className="empty">
            <Circle size={30} aria-hidden="true" />
            <h2>Nothing to remember.</h2>
            <p>That's either excellent or suspicious.</p>
          </div>
        ) : (
          <ul className="reminder-list" aria-label="Reminders">
            {sorted.map((reminder) => {
              const activeIndex = active.findIndex((item) => item.id === reminder.id)
              return (
                <li key={reminder.id} className={reminder.is_done ? 'done' : ''}>
                  <button
                    className="check-button"
                    type="button"
                    aria-label={reminder.is_done ? `Mark "${reminder.text}" active` : `Complete "${reminder.text}"`}
                    aria-pressed={reminder.is_done}
                    title={reminder.is_done ? 'Mark active' : 'Complete'}
                    onClick={() => void patch(reminder.id, { is_done: !reminder.is_done })}
                  >
                    {reminder.is_done ? <Check size={17} aria-hidden="true" /> : <Circle size={19} aria-hidden="true" />}
                  </button>
                  {editingId === reminder.id ? (
                    <form className="edit-form" onSubmit={(event) => { event.preventDefault(); void saveEdit(reminder.id) }}>
                      <input
                        value={editText}
                        onChange={(event) => setEditText(event.target.value)}
                        onKeyDown={(event) => { if (event.key === 'Escape') setEditingId(null) }}
                        maxLength={500}
                        aria-label={`Edit reminder: ${reminder.text}`}
                        autoFocus
                      />
                      <button type="submit" aria-label="Save reminder" title="Save"><Check size={17} aria-hidden="true" /></button>
                      <button type="button" aria-label="Cancel editing" title="Cancel" onClick={() => setEditingId(null)}><X size={17} aria-hidden="true" /></button>
                    </form>
                  ) : (
                    <span className="reminder-text">{reminder.text}</span>
                  )}
                  {editingId !== reminder.id && (
                    <div className="actions">
                      {!reminder.is_done && <>
                        <button type="button" aria-label={`Move "${reminder.text}" up`} title="Move up" disabled={reordering || activeIndex === 0} onClick={() => void move(activeIndex, -1)}><ArrowUp size={16} aria-hidden="true" /></button>
                        <button type="button" aria-label={`Move "${reminder.text}" down`} title="Move down" disabled={reordering || activeIndex === activeCount - 1} onClick={() => void move(activeIndex, 1)}><ArrowDown size={16} aria-hidden="true" /></button>
                      </>}
                      <button type="button" aria-label={`Edit "${reminder.text}"`} title="Edit" onClick={() => { setEditingId(reminder.id); setEditText(reminder.text) }}><Pencil size={16} aria-hidden="true" /></button>
                      <button type="button" aria-label={`Delete "${reminder.text}"`} title="Delete" onClick={() => void remove(reminder.id)}><Trash2 size={16} aria-hidden="true" /></button>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </section>
      <AgentAccess userId={session.user.id} />
      <footer className="board-footer">
        <p className="footer-note"><Smartphone size={16} aria-hidden="true" /> Open the app once after signing in to add the lock-screen widget.</p>
        <LegalFooterLinks onNavigate={onNavigate} />
      </footer>
      {confirmDelete && (
        <div
          className="delete-dialog-backdrop"
          role="presentation"
          onClick={() => { if (!deletingAccount) setConfirmDelete(false) }}
        >
          <div
            className="delete-dialog"
            role="alertdialog"
            aria-modal="true"
            aria-labelledby="delete-account-title"
            aria-describedby="delete-account-copy"
            onClick={(event) => event.stopPropagation()}
          >
            <h2 id="delete-account-title">Delete your account?</h2>
            <p id="delete-account-copy">
              This permanently removes your reminders, device registrations, agent keys, and sign-in.
              This cannot be undone.
            </p>
            <div className="delete-dialog-actions">
              <button
                className="danger"
                type="button"
                disabled={deletingAccount}
                onClick={() => void deleteAccount()}
              >
                {deletingAccount ? 'Deleting…' : 'Delete forever'}
              </button>
              <button
                className="text-button"
                type="button"
                disabled={deletingAccount}
                autoFocus
                onClick={() => setConfirmDelete(false)}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}

type AgentTokenClient = {
  id: string
  name: string
  created_at: string
  last_used_at: string | null
  revoked_at: string | null
}

function AgentAccess({ userId }: { userId: string }) {
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

  return (
    <section className="agent-access" aria-labelledby="agent-access-heading">
      <h2 id="agent-access-heading">Agent access</h2>
      <p>
        In Grok, Claude, Cursor, or Codex, add the plugin or paste {MCP_URL}.
        Sign in when asked. That is the usual path — no tokens to copy.
      </p>
      <details className="agent-snippets">
        <summary>Advanced: personal keys</summary>
        <p>Only if a client cannot sign in. Mint a key below, then paste it once. Shown once. Revoke anytime.</p>
        <form className="agent-key-form" onSubmit={mint}>
          <label className="visually-hidden" htmlFor="agent-key-name">Key name</label>
          <input
            id="agent-key-name"
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Cursor, Codex, Grok Bot…"
            maxLength={64}
            autoComplete="off"
          />
          <button className="primary" type="submit" disabled={busy || !name.trim()}>
            {busy ? 'Creating…' : 'Create key'}
          </button>
        </form>
        {error && <p className="error" role="alert">{error}</p>}
        {minted && (
          <div className="minted-key" role="status">
            <p>Copy this now. It will not be shown again.</p>
            <input readOnly value={minted} onFocus={(event) => event.currentTarget.select()} aria-label="New agent token" />
            <button className="text-button" type="button" onClick={() => setMinted(null)}>I saved it</button>
          </div>
        )}
        {tokens.length > 0 && (
          <ul className="agent-token-list" aria-label="Active agent keys">
            {tokens.map((token) => (
              <li key={token.id}>
                <div>
                  <strong>{token.name}</strong>
                  <span>Created {new Date(token.created_at).toLocaleString()}</span>
                  {token.last_used_at && <span>Last used {new Date(token.last_used_at).toLocaleString()}</span>}
                </div>
                <button className="text-button danger-text" type="button" disabled={busy} onClick={() => void revoke(token.id)}>
                  Revoke
                </button>
              </li>
            ))}
          </ul>
        )}
        <p>Cursor <code>~/.cursor/mcp.json</code></p>
        <pre>{`{
  "mcpServers": {
    "lazy-mans-reminders": {
      "url": "${MCP_URL}"
    }
  }
}`}</pre>
        <p>Claude Code / Codex <code>.mcp.json</code></p>
        <pre>{`{
  "mcpServers": {
    "lazy-mans-reminders": {
      "type": "http",
      "url": "${MCP_URL}"
    }
  }
}`}</pre>
        <p>Grok: Settings → Plugins → custom connector. URL only: <code>{MCP_URL}</code>.</p>
        <p>Personal key header, if you must: <code>Authorization: Bearer TOKEN</code>.</p>
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
      '/connect': "Connect an agent · Lazy Man's Reminders",
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

  if (path === '/auth/callback') return <AuthCallback />
  if (path === '/privacy') return <PrivacyPage onNavigate={navigate} />
  if (path === '/terms') return <TermsPage onNavigate={navigate} />
  if (path === '/support') return <SupportPage onNavigate={navigate} />

  if (!ready) return <div className="splash" role="status" aria-label="Loading">LM</div>
  if (authError) {
    return (
      <main className="fatal-error" role="alert">
        <h1>Could not start the app</h1>
        <p>{authError}</p>
        <button className="primary" type="button" onClick={() => window.location.reload()}>Try again</button>
      </main>
    )
  }
  if (path === '/connect') {
    return session
      ? <Connect session={session} />
      : <SignIn onNavigate={navigate} />
  }

  return session
    ? <Board session={session} onNavigate={navigate} />
    : <SignIn onNavigate={navigate} />
}
