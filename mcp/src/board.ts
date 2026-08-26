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
  if (stored.length > 500) return { kind: 'invalid_text' }
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

export function boardErrorFromStorage(message: string, details?: string): Exclude<BoardError, { kind: 'capacity' }> {
  if (`${message}\n${details ?? ''}`.includes('LMR_INVALID_TEXT')) return { kind: 'invalid_text' }
  return { kind: 'storage', message }
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
  const [{ data, error }, prefs] = await Promise.all([
    supabase
      .from('reminders')
      .select('id, text, is_done, sort_order, created_at, completed_at')
      .eq('user_id', session.userId)
      .order('is_done')
      .order('sort_order')
      .order('created_at'),
    supabase
      .from('lock_screen_prefs')
      .select('max_lines')
      .eq('user_id', session.userId)
      .maybeSingle(),
  ])
  if (error) return { kind: 'storage', message: error.message }

  const rows = (data ?? []) as ReminderSelect[]
  const used = rows.filter((row) => !row.is_done).length
  const capacity = capacityFromUsed(used, effectiveMaximum(prefs.data?.max_lines))
  const reminders = rows.filter((row) => {
    if (status === 'all') return true
    if (status === 'completed') return row.is_done
    return !row.is_done
  })
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
    return { kind: 'storage', message: 'Add returned no row' }
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

  const { data, error } = await supabase
    .from('reminders')
    .update({ is_done: isDone })
    .eq('id', reminderId)
    .eq('user_id', session.userId)
    .select('id, text, is_done, sort_order, created_at, completed_at')
    .maybeSingle()
  if (error) return { kind: 'storage', message: error.message }
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
  }
}
