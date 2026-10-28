import { describe, expect, it } from 'vitest'
import { localDate, routineSummary, weeklyStartDate } from './routines'

describe('routine schedules', () => {
  it('chooses the reminder night rather than the uniform day', () => {
    expect(weeklyStartDate(1, 'UTC', new Date('2026-10-13T12:00:00Z'))).toBe('2026-10-19')
    expect(weeklyStartDate(1, 'UTC', new Date('2026-10-12T20:00:00Z'))).toBe('2026-10-12')
  })
  it('formats calendar dates without converting them to UTC', () => {
    expect(localDate(new Date(2026, 11, 31, 23))).toBe('2026-12-31')
    expect(weeklyStartDate(1, 'UTC', new Date('2026-12-31T23:00:00Z'))).toBe('2027-01-04')
  })
  it.each([
    ['America/New_York', '2026-10-26T01:00:00Z', 0, '2026-10-25'],
    ['Asia/Bangkok', '2026-10-25T23:00:00Z', 0, '2026-11-01'],
    ['Pacific/Kiritimati', '2026-12-31T12:00:00Z', 5, '2027-01-01'],
    ['America/New_York', '2027-01-01T01:00:00Z', 4, '2026-12-31'],
    ['America/New_York', '2026-03-08T04:30:00Z', 0, '2026-03-08'],
    ['America/New_York', '2026-11-01T03:30:00Z', 1, '2026-11-02'],
  ])('uses the calendar in %s at %s', (timezone, now, weekday, expected) => {
    expect(weeklyStartDate(weekday, timezone, new Date(now))).toBe(expected)
  })
  it('shows the cadence and pinned timezone', () => {
    const routine = { id: 'id', text: 'Uniform', interval_days: 7, start_date: '2026-10-12', local_time: '19:00:00', timezone: 'Asia/Singapore', enabled: true, next_run_at: '2026-10-12T11:00:00Z' }
    expect(routineSummary(routine)).toBe('Every Monday at 19:00 · Asia/Singapore')
    expect(routineSummary({ ...routine, interval_days: 3 })).toBe('Every 3 days at 19:00 · Asia/Singapore')
  })
})
