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
import { LegalFooterLinks, PrivacyPage, SupportPage, TermsPage } from './LegalPages'
import { supabase } from './supabase'

type AppRoute = '/' | '/privacy' | '/terms' | '/support'

function normalizePath(pathname: string): AppRoute {
  const path = pathname.replace(/\/+$/, '') || '/'
  if (path === '/privacy' || path === '/terms' || path === '/support') return path
  return '/'
}

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
    const { error: authError } = await supabase.auth.signInWithOtp({
      email: normalizedEmail,
      options: { emailRedirectTo: `${window.location.origin}/` },
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
    const { error: authError } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${window.location.origin}/`,
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
          <Smartphone size={24} />
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
                  onClick={() => void signInWithProvider('apple')}
                >
                  {oauthLoading === 'apple' ? 'Redirecting…' : 'Continue with Apple'}
                </button>
                <button
                  className="oauth-button oauth-google"
                  type="button"
                  disabled={busy}
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

  const sorted = useMemo(
    () => [...reminders].sort((a, b) =>
      Number(a.is_done) - Number(b.is_done)
      || a.sort_order - b.sort_order
      || a.created_at.localeCompare(b.created_at)
      || a.id.localeCompare(b.id),
    ),
    [reminders],
  )
  const active = useMemo(() => sorted.filter((item) => !item.is_done), [sorted])

  const load = useCallback(async () => {
    const sequence = ++loadSequence.current
    const { data, error: fetchError } = await supabase
      .from('reminders')
      .select('id, user_id, text, sort_order, is_done, created_at')
      .eq('user_id', session.user.id)
      .order('is_done')
      .order('sort_order')
      .order('created_at')
    if (sequence !== loadSequence.current) return
    if (fetchError) setError(fetchError.message)
    else setReminders(data ?? [])
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
    setAdding(true)
    setText('')
    setError('')
    const nextOrder = Math.max(-1, ...reminders.map((item) => item.sort_order)) + 1
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
    setReminders((items) => items.map((item) =>
      item.id === a.id ? { ...item, sort_order: b.sort_order } :
      item.id === b.id ? { ...item, sort_order: a.sort_order } : item,
    ))
    const temporaryOrder = Math.min(...reminders.map((item) => item.sort_order)) - 1
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
      // Fallback: clear user-owned rows via RLS, then sign out with support instructions.
      const [{ error: remindersError }, { error: tokensError }] = await Promise.all([
        supabase.from('reminders').delete().eq('user_id', session.user.id),
        supabase.from('device_tokens').delete().eq('user_id', session.user.id),
      ])
      if (remindersError || tokensError) {
        setError(
          remindersError?.message
          ?? tokensError?.message
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
      <header>
        <div>
          <p className="eyebrow">Lazy Man's Reminders</p>
          <h1>Your board</h1>
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
            <LogOut size={18} />
          </button>
        </div>
      </header>

      <section className="board">
        <form className="add-form" onSubmit={add}>
          <Plus size={22} />
          <input
            value={text}
            onChange={(event) => setText(event.target.value)}
            placeholder="What shouldn't you forget?"
            maxLength={500}
            autoFocus
            aria-label="New reminder"
          />
          <button className="primary" type="submit" disabled={!text.trim() || adding}>
            {adding ? 'Adding…' : 'Add'}
          </button>
        </form>
        <div className="board-meta">
          <span>{activeCount} {activeCount === 1 ? 'thing' : 'things'} on your mind</span>
          <span>Updates sync to your lock screen</span>
        </div>
        {error && (
          <div className="error-banner" role="alert">
            <span>{error}</span>
            <button type="button" aria-label="Dismiss error" onClick={() => setError('')}><X size={16} /></button>
          </div>
        )}
        {loading ? (
          <div className="empty" role="status">Loading your board…</div>
        ) : sorted.length === 0 ? (
          <div className="empty">
            <Circle size={30} />
            <h2>Nothing to remember.</h2>
            <p>That's either excellent or suspicious.</p>
          </div>
        ) : (
          <ul className="reminder-list">
            {sorted.map((reminder) => {
              const activeIndex = active.findIndex((item) => item.id === reminder.id)
              return (
                <li key={reminder.id} className={reminder.is_done ? 'done' : ''}>
                  <button
                    className="check-button"
                    type="button"
                    aria-label={reminder.is_done ? `Mark "${reminder.text}" active` : `Complete "${reminder.text}"`}
                    title={reminder.is_done ? 'Mark active' : 'Complete'}
                    onClick={() => void patch(reminder.id, { is_done: !reminder.is_done })}
                  >
                    {reminder.is_done ? <Check size={17} /> : <Circle size={19} />}
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
                      <button type="submit" aria-label="Save reminder" title="Save"><Check size={17} /></button>
                      <button type="button" aria-label="Cancel editing" title="Cancel" onClick={() => setEditingId(null)}><X size={17} /></button>
                    </form>
                  ) : (
                    <span className="reminder-text">{reminder.text}</span>
                  )}
                  {editingId !== reminder.id && (
                    <div className="actions">
                      {!reminder.is_done && <>
                        <button type="button" aria-label={`Move "${reminder.text}" up`} title="Move up" disabled={reordering || activeIndex === 0} onClick={() => void move(activeIndex, -1)}><ArrowUp size={16} /></button>
                        <button type="button" aria-label={`Move "${reminder.text}" down`} title="Move down" disabled={reordering || activeIndex === activeCount - 1} onClick={() => void move(activeIndex, 1)}><ArrowDown size={16} /></button>
                      </>}
                      <button type="button" aria-label={`Edit "${reminder.text}"`} title="Edit" onClick={() => { setEditingId(reminder.id); setEditText(reminder.text) }}><Pencil size={16} /></button>
                      <button type="button" aria-label={`Delete "${reminder.text}"`} title="Delete" onClick={() => void remove(reminder.id)}><Trash2 size={16} /></button>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </section>
      <footer className="board-footer">
        <p className="footer-note"><Smartphone size={16} /> Open the app once after signing in to add the lock-screen widget.</p>
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
              This permanently removes your reminders, device registrations, and sign-in.
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

export default function App() {
  const [path, navigate] = usePathname()
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(false)
  const [authError, setAuthError] = useState('')

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
  return session
    ? <Board session={session} onNavigate={navigate} />
    : <SignIn onNavigate={navigate} />
}
