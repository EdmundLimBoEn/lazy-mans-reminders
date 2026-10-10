import { describe, expect, it, vi } from 'vitest'
import { moveActiveReminder, persistReminderOrder } from './reminderOrder'
import { sortReminders } from './reminders'

const items = [
  { id: 'a', sort_order: 2, is_done: false, created_at: '2026-01-01' },
  { id: 'b', sort_order: 5, is_done: false, created_at: '2026-01-01' },
  { id: 'c', sort_order: 8, is_done: false, created_at: '2026-01-01' },
  { id: 'done', sort_order: 4, is_done: true, created_at: '2026-01-01' },
]

describe('moveActiveReminder', () => {
  it.each([
    ['a', 'c', ['b', 'c', 'a', 'done']],
    ['c', 'a', ['c', 'a', 'b', 'done']],
  ])('moves %s to %s while shifting intervening notes', (source, target, expected) => {
    const result = moveActiveReminder(items, source, target)
    expect(sortReminders(result).map((item) => item.id)).toEqual(expected)
    expect(result[3]).toBe(items[3])
    expect(items.map((item) => item.sort_order)).toEqual([2, 5, 8, 4])
  })

  it('handles duplicate sort orders from older notes', () => {
    const tied = items.map((item) => ({ ...item, sort_order: 0 }))
    expect(sortReminders(moveActiveReminder(tied, 'a', 'c')).map((item) => item.id)).toEqual(['b', 'c', 'a', 'done'])
  })

  it.each([['a', 'a'], ['missing', 'a'], ['a', 'done']])('ignores invalid or unchanged drops', (source, target) => {
    expect(moveActiveReminder(items, source, target)).toBe(items)
  })
})

describe('persistReminderOrder', () => {
  it('persists the order that another board load will display', async () => {
    let stored = items
    const reordered = moveActiveReminder(items, 'a', 'c')
    await persistReminderOrder(items, reordered, async (id, sort_order) => {
      stored = stored.map((item) => item.id === id ? { ...item, sort_order } : item)
    })
    expect(sortReminders(stored).map((item) => item.id)).toEqual(['b', 'c', 'a', 'done'])
  })

  it('restores successful writes when a later write fails', async () => {
    const failure = new Error('Offline')
    const update = vi.fn().mockResolvedValue(undefined).mockResolvedValueOnce(undefined).mockRejectedValueOnce(failure)
    await expect(persistReminderOrder(items, moveActiveReminder(items, 'a', 'c'), update)).rejects.toBe(failure)
    expect(update.mock.calls).toEqual([['b', 0], ['c', 1], ['b', 5]])
  })

  it('does not write unchanged notes', async () => {
    const update = vi.fn()
    await persistReminderOrder(items, items, update)
    expect(update).not.toHaveBeenCalled()
  })
})
