import { describe, expect, it } from 'vitest'
import { localDate, routineSummary, weeklyStartDate } from './routines'

describe('routine schedules', () => {
  it('chooses the reminder night rather than the uniform day', () => {
    expect(weeklyStartDate(1, new Date(2026, 9, 13, 12))).toBe('2026-10-19')
    expect(weeklyStartDate(1, new Date(2026, 9, 12, 20))).toBe('2026-10-12')
  })
  it('formats calendar dates without converting them to UTC', () => {
    expect(localDate(new Date(2026, 11, 31, 23))).toBe('2026-12-31')
    expect(weeklyStartDate(1, new Date(2026, 11, 31, 23))).toBe('2027-01-04')
  })
  it('shows the cadence and pinned timezone', () => {
    const routine = { id: 'id', text: 'Uniform', interval_days: 7, start_date: '2026-10-12', local_time: '19:00:00', timezone: 'Asia/Singapore', enabled: true, next_run_at: '2026-10-12T11:00:00Z' }
    expect(routineSummary(routine)).toBe('Every Monday at 19:00 · Asia/Singapore')
    expect(routineSummary({ ...routine, interval_days: 3 })).toBe('Every 3 days at 19:00 · Asia/Singapore')
  })
})
