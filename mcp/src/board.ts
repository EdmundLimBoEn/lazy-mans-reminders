import type { SupabaseClient } from '@supabase/supabase-js'
import type {
  AgentSession,
  BoardCommand,
  BoardError,
  BoardResult,
  BoardSnapshot,
  Capacity,
  PrefixResult,
  ReminderRow,
} from './domain'

export const DEFAULT_LOCK_SCREEN_MAX_LINES = 6
export const MCP_MAX_LINES_CAP = 16
export const POST_IT_HINT =
  'Hint: This board is more like a post-it note. Combine reminders into one line, or find other ways to keep it short.'

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

type ReminderSelect = ReminderRow & { user_id?: string }

export function prefixAgentText(input: {
  text: string
  agentName: string
}): PrefixResult {
  const trimmed = input.text.trim()
  if (trimmed.length < 1) return { kind: 'invalid_text' }
  const name = input.agentName.trim()
  const stored = name === '' ? trimmed : `[${name}] ${trimmed}`
  // Match PostgreSQL char_length, including the agent prefix.
  if ([...stored].length > 500) return { kind: 'invalid_text' }
  return { kind: 'ok', text: stored }
}

export function effectiveMaximum(syncedMaxLines: number | null | undefined): number {
  const value = syncedMaxLines ?? DEFAULT_LOCK_SCREEN_MAX_LINES
  return Math.min(MCP_MAX_LINES_CAP, Math.max(1, value))
}

export function capacityFromUsed(used: number, maximum: number): Capacity {
  return { used, maximum, remaining: Math.max(0, maximum - used) }
}

export function capacityMaximumFromError(message: string, details?: string): number | null {
  const blob = `${message}\n${details ?? ''}`
  if (!blob.includes('LMR_CAPACITY_REACHED')) return null
  const fromDetail = Number.parseInt(details ?? '', 10)
  return Number.isFinite(fromDetail) && fromDetail > 0 ? fromDetail : MCP_MAX_LINES_CAP
}

export const CLIENT_STORAGE_ERROR = 'Could not update the board. Try again.'

export function boardErrorFromStorage(message: string, details?: string): Exclude<BoardError, { kind: 'capacity' }> {
  if (`${message}\n${details ?? ''}`.includes('LMR_INVALID_TEXT')) return { kind: 'invalid_text' }
  console.error('board storage failed', message, details ?? '')
  return { kind: 'storage', message: CLIENT_STORAGE_ERROR }
}

export function capacityError(snapshot: BoardSnapshot): Extract<BoardError, { kind: 'capacity' }> {
  return {
    kind: 'capacity',
    maxLines: snapshot.capacity.maximum,
    hint: POST_IT_HINT,
    snapshot,
  }
}

export async function runBoardCommand(
  supabase: SupabaseClient,
  session: AgentSession,
  command: BoardCommand,
): Promise<BoardResult> {
  switch (command.kind) {
    case 'list':
      return listBoard(supabase, session, command.status)
    case 'add':
      return addReminder(supabase, session, command.text)
    case 'complete':
      return setCompletion(supabase, session, command.reminderId, true)
    case 'reopen':
      return setCompletion(supabase, session, command.reminderId, false)
    default: {
      const _exhaustive: never = command
      return _exhaustive
    }
  }
}

async function listBoard(
  supabase: SupabaseClient,
  session: AgentSession,
  status: 'active' | 'completed' | 'all',
): Promise<BoardResult> {
  const [active, prefs] = await Promise.all([
    supabase
      .from('reminders')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', session.userId)
      .eq('is_done', false)
      .or('snoozed_until.is.null,snoozed_until.lte.now'),
    supabase
      .from('lock_screen_prefs')
      .select('max_lines')
      .eq('user_id', session.userId)
      .maybeSingle(),
  ])
  if (active.error) return boardErrorFromStorage(active.error.message, active.error.details)
  if (active.count === null) return boardErrorFromStorage('Active count missing')
  if (prefs.error) return boardErrorFromStorage(prefs.error.message, prefs.error.details)

  const reminders: ReminderSelect[] = []
  const pageSize = 1000
  let afterId: string | undefined
  while (true) {
    let query = supabase
      .from('reminders')
      .select('id, text, is_done, sort_order, created_at, completed_at, snoozed_until')
      .eq('user_id', session.userId)
    if (status === 'active') query = query.or('snoozed_until.is.null,snoozed_until.lte.now')
    if (status !== 'all') query = query.eq('is_done', status === 'completed')
    if (afterId !== undefined) query = query.gt('id', afterId)
    const { data, error } = await query
      .order('id')
      .range(0, pageSize - 1)
    if (error) return boardErrorFromStorage(error.message, error.details)
    const page = (data ?? []) as ReminderSelect[]
    reminders.push(...page)
    // A short page may reflect a smaller server cap, so read until empty.
    if (page.length === 0) break
    // An ID cursor survives deletion of earlier rows and smaller server page caps.
    afterId = page[page.length - 1].id
  }
  reminders.sort((a, b) =>
    Number(a.is_done) - Number(b.is_done) ||
    a.sort_order - b.sort_order ||
    a.created_at.localeCompare(b.created_at) ||
    a.id.localeCompare(b.id))
  const capacity = capacityFromUsed(active.count, effectiveMaximum(prefs.data?.max_lines))
  return { kind: 'snapshot', snapshot: { reminders, capacity } }
}

async function addReminder(
  supabase: SupabaseClient,
  session: AgentSession,
  text: string,
): Promise<BoardResult> {
  const prefixed = prefixAgentText({ text, agentName: session.agentName })
  if (prefixed.kind === 'invalid_text') return prefixed

  const { data, error } = await supabase.rpc('add_agent_reminder', {
    p_user_id: session.userId,
    p_text: prefixed.text,
  })
  if (error) {
    if (capacityMaximumFromError(error.message, error.details) !== null) {
      const listed = await listBoard(supabase, session, 'active')
      if (listed.kind === 'snapshot') return capacityError(listed.snapshot)
      const maximum = capacityMaximumFromError(error.message, error.details) ?? MCP_MAX_LINES_CAP
      return capacityError({
        reminders: [],
        capacity: capacityFromUsed(maximum, maximum),
      })
    }
    return boardErrorFromStorage(error.message, error.details)
  }

  const row = Array.isArray(data) ? data[0] : data
  if (!row || typeof row !== 'object') {
    return boardErrorFromStorage('Add returned no row')
  }
  const written = row as ReminderSelect & {
    capacity_maximum?: number
    active_count?: number
  }
  const maximum = effectiveMaximum(written.capacity_maximum)
  const used = typeof written.active_count === 'number' ? written.active_count : 0
  return {
    kind: 'written',
    reminder: toReminderRow(written),
    capacity: capacityFromUsed(used, maximum),
  }
}

async function setCompletion(
  supabase: SupabaseClient,
  session: AgentSession,
  reminderId: string,
  isDone: boolean,
): Promise<BoardResult> {
  if (!UUID.test(reminderId)) return { kind: 'not_found' }

  const query = isDone
    ? supabase.from('reminders').update({ is_done: true }).eq('id', reminderId).eq('user_id', session.userId).eq('is_done', false)
    : supabase.rpc('reopen_reminder', { p_user_id: session.userId, p_reminder_id: reminderId })
  const { data, error } = await query
    .select('id, text, is_done, sort_order, created_at, completed_at, snoozed_until')
    .maybeSingle()
  if (error) {
    const maximum = capacityMaximumFromError(error.message, error.details)
    if (!isDone && maximum !== null) {
      const listed = await listBoard(supabase, session, 'active')
      // Reopening is governed by the hard quota, not the lock-screen preference.
      return capacityError({
        reminders: listed.kind === 'snapshot' ? listed.snapshot.reminders : [],
        capacity: capacityFromUsed(
          listed.kind === 'snapshot' ? listed.snapshot.capacity.used : maximum,
          maximum,
        ),
      })
    }
    return boardErrorFromStorage(error.message, error.details)
  }
  if (!data && isDone) {
    const existing = await supabase.from('reminders')
      .select('id, text, is_done, sort_order, created_at, completed_at, snoozed_until')
      .eq('id', reminderId).eq('user_id', session.userId).eq('is_done', true)
      .maybeSingle()
    if (existing.error) return boardErrorFromStorage(existing.error.message, existing.error.details)
    if (existing.data) return { kind: 'changed', reminder: toReminderRow(existing.data as ReminderSelect) }
  }
  if (!data) return { kind: 'not_found' }
  return { kind: 'changed', reminder: toReminderRow(data as ReminderSelect) }
}

function toReminderRow(row: ReminderSelect): ReminderRow {
  return {
    id: row.id,
    text: row.text,
    is_done: row.is_done,
    sort_order: row.sort_order,
    created_at: row.created_at,
    completed_at: row.completed_at ?? null,
    snoozed_until: row.snoozed_until ?? null,
  }
}
