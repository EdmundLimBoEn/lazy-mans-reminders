import { describe, expect, it } from 'vitest'
import {
  nextSortOrder,
  sortReminders,
  swapSortOrders,
  temporarySortOrder,
  isAtCapacity,
  isStaleCompletedReminder,
  COMPLETED_REMINDER_RETENTION_DAYS,
  DEFAULT_LOCK_SCREEN_MAX_LINES,
  POST_IT_HINT,
  type ReminderLike,
} from './reminders'

function reminder(partial: Partial<ReminderLike> & Pick<ReminderLike, 'id'>): ReminderLike {
  return {
    sort_order: 0,
    is_done: false,
    created_at: '2026-01-01T00:00:00Z',
    ...partial,
  }
}

describe('sortReminders', () => {
  it('puts incomplete ahead of done, then by sort_order', () => {
    const sorted = sortReminders([
      reminder({ id: 'done-early', is_done: true, sort_order: 0 }),
      reminder({ id: 'active-b', sort_order: 2 }),
      reminder({ id: 'active-a', sort_order: 1 }),
    ])
    expect(sorted.map((item) => item.id)).toEqual(['active-a', 'active-b', 'done-early'])
  })

  it('breaks ties with created_at then id', () => {
    const sorted = sortReminders([
      reminder({ id: 'b', sort_order: 1, created_at: '2026-01-02T00:00:00Z' }),
      reminder({ id: 'a', sort_order: 1, created_at: '2026-01-02T00:00:00Z' }),
      reminder({ id: 'c', sort_order: 1, created_at: '2026-01-01T00:00:00Z' }),
    ])
    expect(sorted.map((item) => item.id)).toEqual(['c', 'a', 'b'])
  })
})

describe('nextSortOrder', () => {
  it('returns 0 for an empty list', () => {
    expect(nextSortOrder([])).toBe(0)
  })

  it('returns max + 1', () => {
    expect(nextSortOrder([
      reminder({ id: 'a', sort_order: 0 }),
      reminder({ id: 'b', sort_order: 4 }),
      reminder({ id: 'c', sort_order: 2 }),
    ])).toBe(5)
  })
})

describe('swapSortOrders', () => {
  it('swaps sort_order between two ids', () => {
    const items = [
      reminder({ id: 'a', sort_order: 1 }),
      reminder({ id: 'b', sort_order: 3 }),
      reminder({ id: 'c', sort_order: 5 }),
    ]
    const swapped = swapSortOrders(items, 'a', 'b')
    expect(swapped.find((item) => item.id === 'a')?.sort_order).toBe(3)
    expect(swapped.find((item) => item.id === 'b')?.sort_order).toBe(1)
    expect(swapped.find((item) => item.id === 'c')?.sort_order).toBe(5)
  })

  it('returns the same array reference when an id is missing', () => {
    const items = [reminder({ id: 'a', sort_order: 1 })]
    expect(swapSortOrders(items, 'a', 'missing')).toBe(items)
  })
})

describe('temporarySortOrder', () => {
  it('is strictly below every existing order', () => {
    expect(temporarySortOrder([
      reminder({ id: 'a', sort_order: 0 }),
      reminder({ id: 'b', sort_order: 2 }),
    ])).toBe(-1)
  })

  it('handles empty lists', () => {
    expect(temporarySortOrder([])).toBe(-1)
  })
})

describe('board capacity', () => {
  it('uses the phone-synced line budget', () => {
    expect(isAtCapacity(0, 6)).toBe(false)
    expect(isAtCapacity(5, 6)).toBe(false)
    expect(isAtCapacity(6, 6)).toBe(true)
    expect(isAtCapacity(8, 6)).toBe(true)
  })

  it('falls back to the default lock-screen budget', () => {
    expect(isAtCapacity(DEFAULT_LOCK_SCREEN_MAX_LINES - 1)).toBe(false)
    expect(isAtCapacity(DEFAULT_LOCK_SCREEN_MAX_LINES)).toBe(true)
  })

  it('clamps a phone budget above 16', () => {
    expect(isAtCapacity(15, 20)).toBe(false)
    expect(isAtCapacity(16, 20)).toBe(true)
  })

  it('exposes the post-it hint copy', () => {
    expect(POST_IT_HINT).toMatch(/post-it note/i)
  })
})

describe('isStaleCompletedReminder', () => {
  const now = new Date('2026-08-08T12:00:00Z')

  it('is false for missing or invalid completed_at', () => {
    expect(isStaleCompletedReminder(null, now)).toBe(false)
    expect(isStaleCompletedReminder(undefined, now)).toBe(false)
    expect(isStaleCompletedReminder('not-a-date', now)).toBe(false)
  })

  it(`is false within ${COMPLETED_REMINDER_RETENTION_DAYS} days (exclusive boundary)`, () => {
    expect(isStaleCompletedReminder('2026-08-01T12:00:00Z', now)).toBe(false)
    expect(isStaleCompletedReminder('2026-08-08T11:00:00Z', now)).toBe(false)
  })

  it(`is true beyond ${COMPLETED_REMINDER_RETENTION_DAYS} days`, () => {
    expect(isStaleCompletedReminder('2026-08-01T11:59:59Z', now)).toBe(true)
    expect(isStaleCompletedReminder('2026-07-01T00:00:00Z', now)).toBe(true)
  })
})
