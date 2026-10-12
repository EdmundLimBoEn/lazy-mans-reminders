export type Routine = {
  id: string
  text: string
  interval_days: number
  start_date: string
  local_time: string
  timezone: string
  enabled: boolean
  next_run_at: string
}

export const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

export function localDate(date = new Date()): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

export function weeklyStartDate(weekday: number, now = new Date()): string {
  const date = new Date(now)
  date.setDate(date.getDate() + (weekday - date.getDay() + 7) % 7)
  return localDate(date)
}

export function routineSummary(routine: Routine): string {
  const cadence = routine.interval_days === 7
    ? `Every ${WEEKDAYS[new Date(`${routine.start_date}T12:00:00`).getDay()]}`
    : routine.interval_days === 1 ? 'Every day' : `Every ${routine.interval_days} days`
  return `${cadence} at ${routine.local_time.slice(0, 5)} · ${routine.timezone}`
}
