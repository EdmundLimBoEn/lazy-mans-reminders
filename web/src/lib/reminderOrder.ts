import { sortReminders, type ReminderLike } from './reminders'

export function moveActiveReminder<T extends ReminderLike>(items: T[], sourceId: string, targetId: string): T[] {
  const active = sortReminders(items).filter((item) => !item.is_done)
  const source = active.findIndex((item) => item.id === sourceId)
  const target = active.findIndex((item) => item.id === targetId)
  if (source < 0 || target < 0 || source === target) return items
  const [moved] = active.splice(source, 1)
  active.splice(target, 0, moved)
  const orders = new Map(active.map((item, index) => [item.id, index]))
  return items.map((item) => orders.has(item.id) ? { ...item, sort_order: orders.get(item.id)! } : item)
}

export async function persistReminderOrder<T extends ReminderLike>(
  after: T[],
  client: { rpc: (name: 'reorder_reminders', args: { p_ids: string[] }) => PromiseLike<{ error: unknown }> },
): Promise<void> {
  const ids = sortReminders(after).filter((item) => !item.is_done).map((item) => item.id)
  const { error } = await client.rpc('reorder_reminders', { p_ids: ids })
  if (error) throw error
}
