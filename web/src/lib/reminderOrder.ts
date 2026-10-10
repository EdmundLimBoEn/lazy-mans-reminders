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
  before: T[],
  after: T[],
  update: (id: string, order: number) => Promise<void>,
): Promise<void> {
  const previous = new Map(before.map((item) => [item.id, item]))
  const saved: T[] = []
  try {
    for (const item of after) {
      const original = previous.get(item.id)
      if (!original || original.sort_order === item.sort_order) continue
      await update(item.id, item.sort_order)
      saved.push(original)
    }
  } catch (error) {
    // Restore successful writes before the caller reloads the server's actual state.
    await Promise.allSettled(saved.map((item) => update(item.id, item.sort_order)))
    throw error
  }
}
