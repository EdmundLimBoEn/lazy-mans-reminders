export type ReminderLike = {
  id: string
  sort_order: number
  is_done: boolean
  created_at: string
}

/** Fallback when the phone hasn't synced `lock_screen_prefs` yet. */
export const DEFAULT_LOCK_SCREEN_MAX_LINES = 6

/** Soft upper bound; real capacity comes from the phone via `lock_screen_prefs`. */
export const MAX_ACTIVE_REMINDERS = 16

/** Done reminders older than this are deleted by `delete_old_completed_reminders()`. */
export const COMPLETED_REMINDER_RETENTION_DAYS = 7

export const POST_IT_HINT =
  'Hint: This board is more like a post-it note. Combine reminders into one line, or find other ways to keep it short.'

export function isAtCapacity(
  activeCount: number,
  maxLines: number = DEFAULT_LOCK_SCREEN_MAX_LINES,
): boolean {
  return activeCount >= effectiveMaximum(maxLines)
}

/** Clamp a phone-synced line budget to the shared 1–16 range. */
export function effectiveMaximum(syncedMaxLines: number | null | undefined): number {
  const value = syncedMaxLines ?? DEFAULT_LOCK_SCREEN_MAX_LINES
  return Math.min(MAX_ACTIVE_REMINDERS, Math.max(1, value))
}

/** True when a completed_at timestamp is older than the retention window. */
export function isStaleCompletedReminder(
  completedAt: string | null | undefined,
  now: Date = new Date(),
  retentionDays = COMPLETED_REMINDER_RETENTION_DAYS,
): boolean {
  if (!completedAt) return false
  const completedMs = Date.parse(completedAt)
  if (Number.isNaN(completedMs)) return false
  return completedMs < now.getTime() - retentionDays * 24 * 60 * 60 * 1000
}

/** Board display order: active first, then sort_order, created_at, id. */
export function sortReminders<T extends ReminderLike>(reminders: T[]): T[] {
  return [...reminders].sort((a, b) =>
    Number(a.is_done) - Number(b.is_done)
    || a.sort_order - b.sort_order
    || a.created_at.localeCompare(b.created_at)
    || a.id.localeCompare(b.id),
  )
}

/** Next sort_order when appending a reminder (max existing + 1, or 0 if empty). */
export function nextSortOrder(reminders: Pick<ReminderLike, 'sort_order'>[]): number {
  return Math.max(-1, ...reminders.map((item) => item.sort_order)) + 1
}

/**
 * Swap sort_order between two reminder ids (used by up/down reorder).
 * Returns a new array; unknown ids are left unchanged.
 */
export function swapSortOrders<T extends ReminderLike>(
  reminders: T[],
  idA: string,
  idB: string,
): T[] {
  const a = reminders.find((item) => item.id === idA)
  const b = reminders.find((item) => item.id === idB)
  if (!a || !b) return reminders
  const orderA = a.sort_order
  const orderB = b.sort_order
  return reminders.map((item) =>
    item.id === idA ? { ...item, sort_order: orderB } :
    item.id === idB ? { ...item, sort_order: orderA } : item,
  )
}

/** Temporary sort_order used during three-step reorder to avoid unique conflicts. */
export function temporarySortOrder(reminders: Pick<ReminderLike, 'sort_order'>[]): number {
  return Math.min(...reminders.map((item) => item.sort_order), 0) - 1
}
