import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { DndContext, closestCenter, PointerSensor, KeyboardSensor, useSensor, useSensors } from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy, sortableKeyboardCoordinates } from '@dnd-kit/sortable'
import { SortableReminder } from './components/SortableReminder'
import { moveActiveReminder, persistReminderOrder } from './lib/reminderOrder'
import { connectionRefresh } from './lib/connectionRefresh'
import type { Session } from '@supabase/supabase-js'
import { ArrowDown, ArrowUp, Check, ChevronRight, Circle, CircleAlert, CircleCheck, Download, KeyRound, LogOut, Pencil, Plus, Smartphone, Trash2, X } from 'lucide-react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertDialog, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SiteHeader } from '@/components/SiteHeader'
import { cn } from '@/lib/utils'
import { accountExportFilename, buildAccountExport, serializeAccountExport, type AccountExportAgentKey, type AccountExportReminder } from './lib/accountExport'
import { nextSortOrder, sortReminders, isAtCapacity, effectiveMaximum, POST_IT_HINT, DEFAULT_LOCK_SCREEN_MAX_LINES } from './lib/reminders'
import { ConnectedAgents } from './ConnectedAgents'
import { LegalFooterLinks } from './LegalPages'
import { AGENT_TOKEN_PLACEHOLDER, LMR_AGENT_TOKEN_VAR, MCP_URL, claudeMcpConfig, cursorMcpConfig, grokConnectorConfig, lmrAgentTokenHeaderTemplate } from './mcp'
import { supabase } from './supabase'
import { RoutineReminders } from './RoutineReminders'
import { ThemeToggle } from './ThemeToggle'

type Reminder = {
  id: string
  user_id: string
  text: string
  sort_order: number
  is_done: boolean
  created_at: string
}

type ReminderChanges = Pick<Reminder, 'is_done' | 'sort_order' | 'text'>

export default function Board({ session, onNavigate, onAccountDeleted }: {
  session: Session
  onNavigate: (path: string) => void
  onAccountDeleted: (manualAppleRevocation: boolean) => void
}) {
  const [reminders, setReminders] = useState<Reminder[]>([])
  const [text, setText] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editText, setEditText] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [adding, setAdding] = useState(false)
  const [reordering, setReordering] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null)
  const deleteButtonRef = useRef<HTMLButtonElement>(null)
  const [deletingAccount, setDeletingAccount] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [maxLines, setMaxLines] = useState(DEFAULT_LOCK_SCREEN_MAX_LINES)
  const loadSequence = useRef(0)
  const reorderingRef = useRef(false)
  const pendingMutationsRef = useRef(new Set<string>())
  const [pendingMutations, setPendingMutations] = useState(new Set<string>())
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  useEffect(() => {
    if (!confirmDelete) return
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !deletingAccount) setConfirmDelete(null)
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
    const recovery = connectionRefresh(async () => {
      if (!reorderingRef.current) await load()
    }, error => { if (error instanceof Error) setError(error.message) })
    let reloadTimer: number | undefined
    const channel = supabase
      .channel(`reminders:${session.user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'reminders', filter: `user_id=eq.${session.user.id}` },
        () => {
          if (reorderingRef.current) return
          window.clearTimeout(reloadTimer)
          reloadTimer = window.setTimeout(() => {
            if (!reorderingRef.current) recovery.refresh()
          }, 100)
        },
      )
      .subscribe(recovery.onStatus)
    return () => {
      recovery.dispose()
      window.clearTimeout(reloadTimer)
      void supabase.removeChannel(channel)
    }
  }, [load, session.user.id])

  async function add(event: FormEvent) {
    event.preventDefault()
    const value = text.trim()
    if (!value || adding || reorderingRef.current) return
    if (isAtCapacity(active.length, maxLines)) {
      setError(POST_IT_HINT)
      return
    }
    ++loadSequence.current
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
    }
    await load()
    setAdding(false)
  }

  async function patch(id: string, changes: Partial<ReminderChanges>) {
    if (reorderingRef.current || pendingMutationsRef.current.has(id)) return false
    const previous = reminders.find((item) => item.id === id)
    if (!previous) return false
    const optimistic = { ...previous, ...changes }
    pendingMutationsRef.current.add(id)
    setPendingMutations(new Set(pendingMutationsRef.current))
    try {
      ++loadSequence.current
      setError('')
      setReminders((items) => items.map((item) => item.id === id ? optimistic : item))
      const { error: updateError } = await supabase
        .from('reminders')
        .update(changes)
        .eq('id', id)
        .eq('user_id', session.user.id)
      if (updateError) {
        // Restore only our optimistic row; preserve any newer state from a read.
        setReminders((items) => items.map((item) => item === optimistic ? previous : item))
        setError(updateError.message)
      }
      // Invalidate reads started during the write and reconcile acknowledged state.
      await load()
      return !updateError
    } finally {
      pendingMutationsRef.current.delete(id)
      setPendingMutations(new Set(pendingMutationsRef.current))
    }
  }

  async function remove(id: string) {
    if (reorderingRef.current || pendingMutationsRef.current.has(id)) return false
    const previous = reminders.find((item) => item.id === id)
    if (!previous) return false
    pendingMutationsRef.current.add(id)
    setPendingMutations(new Set(pendingMutationsRef.current))
    try {
      ++loadSequence.current
      setError('')
      setReminders((items) => items.filter((item) => item.id !== id))
      const { error: deleteError } = await supabase
        .from('reminders')
        .delete()
        .eq('id', id)
        .eq('user_id', session.user.id)
      if (deleteError) {
        // The per-row guard remains held through rollback and reconciliation.
        setReminders((items) => items.some((item) => item.id === id) ? items : [...items, previous])
        setError(deleteError.message)
      }
      await load()
      return !deleteError
    } finally {
      pendingMutationsRef.current.delete(id)
      setPendingMutations(new Set(pendingMutationsRef.current))
    }
  }

  async function reorder(sourceId: string, targetId: string) {
    if (reorderingRef.current || pendingMutationsRef.current.size > 0 || editingId || adding) return
    const reordered = moveActiveReminder(reminders, sourceId, targetId)
    if (reordered === reminders) return
    ++loadSequence.current
    reorderingRef.current = true
    setReordering(true)
    setError('')
    setReminders(reordered)
    try {
      await persistReminderOrder(reordered, supabase)
    } catch (error) {
      setReminders(reminders)
      setError(error instanceof Error || (typeof error === 'object' && error && 'message' in error)
        ? String(error.message) : 'Could not reorder reminders')
    } finally {
      try {
        await load()
      } finally {
        reorderingRef.current = false
        setReordering(false)
      }
    }
  }

  async function move(index: number, direction: -1 | 1) {
    const target = active[index + direction]
    if (active[index] && target) await reorder(active[index].id, target.id)
  }

  async function saveEdit(id: string) {
    const value = editText.trim()
    if (value && await patch(id, { text: value })) {
      setEditingId((current) => current === id ? null : current)
    }
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
    const [{ data: reminderRows, error: reminderError }, { data: prefs, error: prefsError }, { data: keys, error: keyError }, { data: routines, error: routineError }] =
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
        supabase.from('routine_reminders').select('id,text,interval_days,start_date,local_time,timezone,enabled,next_run_at').eq('user_id', session.user.id),
      ])
    if (reminderError || prefsError || keyError || routineError) {
      setError(reminderError?.message ?? prefsError?.message ?? keyError?.message ?? routineError?.message ?? 'Could not export your data.')
      setExporting(false)
      return
    }
    const payload = buildAccountExport({
      email: session.user.email ?? null,
      userId: session.user.id,
      maxLines: typeof prefs?.max_lines === 'number' ? prefs.max_lines : maxLines,
      reminders: (reminderRows ?? []) as AccountExportReminder[],
      routines: routines ?? [],
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
    if (!confirmDelete) return
    const expectedUserId = confirmDelete
    setDeletingAccount(true)
    setError('')
    const { data: current, error: sessionError } = await supabase.auth.getSession()
    if (sessionError || current.session?.user.id !== expectedUserId) {
      setError('Your signed-in account changed. Please reopen account deletion and try again.')
      setConfirmDelete(null)
      setDeletingAccount(false)
      return
    }
    const { data, error: invokeError } = await supabase.functions.invoke('delete-account', {
      method: 'POST',
      body: { expectedUserId },
    })
    if (invokeError || data?.ok !== true) {
      setError(
        invokeError?.message
          ?? 'Could not delete your account. Stay signed in and try again, or email support from the Support page.',
      )
      setDeletingAccount(false)
      return
    }
    onAccountDeleted(data?.appleRevocation === 'manual_required')
    await supabase.auth.signOut({ scope: 'local' })
    setConfirmDelete(null)
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
                disabled={boardFull || adding || reordering}
                aria-label="New reminder"
                aria-describedby="board-hint board-capacity"
              />
            </div>
            <Button type="submit" disabled={boardFull || !text.trim() || adding || reordering} aria-busy={adding || undefined}>
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
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={({ active: dragged, over }) => {
                  if (over) void reorder(String(dragged.id), String(over.id))
                }}
              >
                <SortableContext items={active.map((item) => item.id)} strategy={verticalListSortingStrategy}>
                  <ul className="reminder-list divide-y" aria-label="Reminders" aria-busy={reordering}>
                    {sorted.map((reminder) => {
                      const pending = pendingMutations.has(reminder.id)
                      const activeIndex = active.findIndex((item) => item.id === reminder.id)
                      return (
                        <SortableReminder
                          key={reminder.id}
                          id={reminder.id}
                          text={reminder.text}
                          disabled={reordering || pendingMutations.size > 0 || adding || reminder.is_done || editingId !== null || active.length < 2}
                          showHandle={!reminder.is_done}
                        >
                          <Button
                            variant="ghost"
                            size="icon"
                            className="shrink-0 text-muted-foreground hover:text-foreground"
                            type="button"
                            aria-label={reminder.is_done ? `Mark "${reminder.text}" active` : `Complete "${reminder.text}"`}
                            aria-pressed={reminder.is_done}
                            title={reminder.is_done ? 'Mark active' : 'Complete'}
                            disabled={reordering || pending}
                            onClick={() => void patch(reminder.id, { is_done: !reminder.is_done })}
                          >
                            {reminder.is_done ? <CircleCheck aria-hidden="true" /> : <Circle aria-hidden="true" />}
                          </Button>
                          {editingId === reminder.id ? (
                            <form className="flex min-w-0 flex-1 items-center gap-1" onSubmit={(event) => { event.preventDefault(); void saveEdit(reminder.id) }}>
                              <Input
                                className="h-8"
                                value={editText}
                                disabled={pending}
                                onChange={(event) => setEditText(event.target.value)}
                                onKeyDown={(event) => { if (event.key === 'Escape') setEditingId(null) }}
                                maxLength={500}
                                aria-label={`Edit reminder: ${reminder.text}`}
                                autoFocus
                              />
                              <Button variant="ghost" size="icon" type="submit" disabled={pending} aria-label="Save reminder" title="Save"><Check aria-hidden="true" /></Button>
                              <Button variant="ghost" size="icon" type="button" disabled={pending} aria-label="Cancel editing" title="Cancel" onClick={() => setEditingId(null)}><X aria-hidden="true" /></Button>
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
                                <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Move "${reminder.text}" up`} title="Move up" disabled={reordering || pendingMutations.size > 0 || activeIndex === 0} onClick={() => void move(activeIndex, -1)}><ArrowUp aria-hidden="true" /></Button>
                                <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Move "${reminder.text}" down`} title="Move down" disabled={reordering || pendingMutations.size > 0 || activeIndex === activeCount - 1} onClick={() => void move(activeIndex, 1)}><ArrowDown aria-hidden="true" /></Button>
                              </>}
                              <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Edit "${reminder.text}"`} title="Edit" disabled={reordering || pending} onClick={() => { setEditingId(reminder.id); setEditText(reminder.text) }}><Pencil aria-hidden="true" /></Button>
                              <Button variant="ghost" size="icon" type="button" className="hover:text-foreground" aria-label={`Delete "${reminder.text}"`} title="Delete" disabled={reordering || pending} onClick={() => void remove(reminder.id)}><Trash2 aria-hidden="true" /></Button>
                            </div>
                          )}
                        </SortableReminder>
                      )
                    })}
                  </ul>
                </SortableContext>
              </DndContext>
            )}
          </div>
        </section>

        <RoutineReminders userId={session.user.id} />

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
              onClick={() => setConfirmDelete(session.user.id)}
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
        open={confirmDelete !== null}
        onOpenChange={(open) => { if (!open && !deletingAccount) setConfirmDelete(null) }}
      >
        <AlertDialogContent
          className="delete-dialog sm:max-w-md"
          overlayProps={{ onClick: () => { if (!deletingAccount) setConfirmDelete(null) } }}
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

