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
  it('sends the complete active order in one call, including unchanged positions', async () => {
    const before = items.map((item, index) => ({ ...item, sort_order: index }))
    const rpc = vi.fn().mockResolvedValue({ error: null })
    await persistReminderOrder(moveActiveReminder(before, 'a', 'b'), { rpc })
    expect(rpc.mock.calls).toEqual([['reorder_reminders', { p_ids: ['b', 'a', 'c'] }]])
  })

  it.each(['returned', 'thrown'])('propagates %s failure for UI rollback without compensating writes', async (kind) => {
    const failure = new Error('The board changed')
    const rpc = kind === 'returned'
      ? vi.fn().mockResolvedValue({ error: failure })
      : vi.fn().mockRejectedValue(failure)
    await expect(persistReminderOrder(moveActiveReminder(items, 'a', 'c'), { rpc })).rejects.toBe(failure)
    expect(rpc.mock.calls).toEqual([['reorder_reminders', { p_ids: ['b', 'c', 'a'] }]])
  })
})
