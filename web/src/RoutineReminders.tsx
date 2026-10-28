import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { supabase } from './supabase'
import { localDate, routineSummary, weeklyStartDate, WEEKDAYS, type Routine } from './lib/routines'

export function RoutineReminders({ userId }: { userId: string }) {
  const [routines, setRoutines] = useState<Routine[]>([])
  const [text, setText] = useState('')
  const [cadence, setCadence] = useState<'weekly' | 'days'>('weekly')
  const [weekday, setWeekday] = useState(1)
  const [days, setDays] = useState('2')
  const [startDate, setStartDate] = useState(localDate)
  const [time, setTime] = useState('19:00')
  const [timezone, setTimezone] = useState(() => Intl.DateTimeFormat().resolvedOptions().timeZone)
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)
  const draftRevision = useRef(0)

  const load = useCallback(async () => {
    const { data, error } = await supabase.from('routine_reminders')
      .select('id,text,interval_days,start_date,local_time,timezone,enabled,next_run_at')
      .eq('user_id', userId).order('created_at')
    if (error) setError(error.message)
    else setRoutines(data ?? [])
    setLoading(false)
  }, [userId])

  useEffect(() => {
    void load()
    const channel = supabase.channel(`routines:${userId}`).on('postgres_changes',
      { event: '*', schema: 'public', table: 'routine_reminders', filter: `user_id=eq.${userId}` },
      () => void load()).subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [load, userId])

  function reset() {
    setText('')
    setEditingId(null)
  }

  async function save(event: FormEvent) {
    event.preventDefault()
    if (busy || !text.trim()) return
    try { new Intl.DateTimeFormat('en', { timeZone: timezone }) } catch {
      setError('Enter a valid timezone, such as Asia/Singapore.')
      return
    }
    setBusy(true)
    setError('')
    const submittedRevision = draftRevision.current
    try {
      const values = {
        text: text.trim(), interval_days: cadence === 'weekly' ? 7 : Number(days),
        start_date: cadence === 'weekly' ? weeklyStartDate(weekday) : startDate,
        local_time: time, timezone,
      }
      const { error } = editingId
        ? await supabase.from('routine_reminders').update(values).eq('id', editingId).eq('user_id', userId)
        : await supabase.from('routine_reminders').insert({ ...values, user_id: userId })
      if (error) setError(error.message)
      else {
        if (draftRevision.current === submittedRevision) reset()
        await load()
      }
    } catch (error) {
      setError(error instanceof Error ? error.message : 'Could not save routine')
    } finally {
      setBusy(false)
    }
  }

  async function change(routine: Routine, remove: boolean) {
    setBusy(true)
    setError('')
    try {
      const query = supabase.from('routine_reminders')
      const { error } = await (remove ? query.delete() : query.update({ enabled: !routine.enabled }))
        .eq('id', routine.id).eq('user_id', userId)
      if (error) setError(error.message)
      else { if (editingId === routine.id) reset(); await load() }
    } catch (error) {
      setError(error instanceof Error ? error.message : 'Could not update routine')
    } finally {
      setBusy(false)
    }
  }

  function edit(routine: Routine) {
    setEditingId(routine.id)
    setText(routine.text)
    setCadence(routine.interval_days === 7 ? 'weekly' : 'days')
    setWeekday(new Date(`${routine.start_date}T12:00:00`).getDay())
    setDays(String(routine.interval_days))
    setStartDate(routine.start_date)
    setTime(routine.local_time.slice(0, 5))
    setTimezone(routine.timezone)
  }

  const selectClass = 'h-9 w-full rounded-md border bg-background px-3 text-sm'
  return <section className="grid gap-4" aria-labelledby="routine-heading">
    <div className="space-y-1">
      <h2 id="routine-heading" className="text-lg font-semibold">Routine reminders</h2>
      <p className="text-sm text-muted-foreground">Repeat at the same local time. For Tuesday's uniform, choose Monday at 7 pm.</p>
      <p className="text-sm text-muted-foreground">When due, the reminder returns to your board and sends a push to your registered iPhone. Completing it keeps the routine running.</p>
    </div>
    <form onSubmit={save} onChange={() => { draftRevision.current += 1 }} className="grid gap-3 rounded-lg border p-4">
      <div className="grid gap-2"><Label htmlFor="routine-text">Reminder</Label>
        <Input id="routine-text" value={text} onChange={e => setText(e.target.value)} placeholder="Prepare Tuesday's uniform" maxLength={500} required /></div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="grid gap-2"><Label htmlFor="routine-repeat">Repeat</Label>
          <select id="routine-repeat" className={selectClass} value={cadence} onChange={e => setCadence(e.target.value === 'weekly' ? 'weekly' : 'days')}>
            <option value="weekly">Every week</option><option value="days">Every N days</option>
          </select></div>
        {cadence === 'weekly' ? <div className="grid gap-2"><Label htmlFor="routine-weekday">Reminder day</Label>
          <select id="routine-weekday" className={selectClass} value={weekday} onChange={e => setWeekday(Number(e.target.value))}>
            {WEEKDAYS.map((day, index) => <option key={day} value={index}>{day}</option>)}
          </select></div> : <>
          <div className="grid gap-2"><Label htmlFor="routine-days">Number of days</Label>
            <Input id="routine-days" type="number" min="1" max="365" step="1" value={days} onChange={e => setDays(e.target.value)} required /></div>
          <div className="grid gap-2"><Label htmlFor="routine-start">Start date</Label>
            <Input id="routine-start" type="date" value={startDate} onChange={e => setStartDate(e.target.value)} required /></div>
        </>}
        <div className="grid gap-2"><Label htmlFor="routine-time">Time</Label>
          <Input id="routine-time" type="time" value={time} onChange={e => setTime(e.target.value)} required /></div>
        <div className="grid gap-2"><Label htmlFor="routine-zone">Timezone</Label>
          <Input id="routine-zone" value={timezone} onChange={e => setTimezone(e.target.value)} required /></div>
      </div>
      <p className="text-xs text-muted-foreground">The timezone stays fixed when you travel. Delivery can take up to a minute, plus network delays.</p>
      <div className="flex gap-2"><Button type="submit" disabled={busy || loading}>{busy ? 'Saving…' : editingId ? 'Save routine' : 'Add routine'}</Button>
        {editingId && <Button type="button" variant="outline" onClick={reset} disabled={busy}>Cancel edit</Button>}</div>
    </form>
    {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
    {loading ? <p role="status" className="text-sm">Loading routines…</p> : routines.length === 0 ? <p className="text-sm text-muted-foreground">No routines yet.</p> :
      <ul className="grid gap-3" aria-label="Routine reminders">{routines.map(routine => <li key={routine.id} className="grid gap-2 rounded-lg border p-4">
        <p className="font-medium break-words">{routine.text}</p>
        <p className="text-sm text-muted-foreground">{routineSummary(routine)}</p>
        <p className="text-sm">{routine.enabled ? `Next: ${new Date(routine.next_run_at).toLocaleString(undefined, { timeZone: routine.timezone })} · ${routine.timezone}` : 'Paused'}</p>
        <div className="flex flex-wrap gap-2">
          <Button size="sm" variant="outline" disabled={busy} onClick={() => edit(routine)}>Edit</Button>
          <Button size="sm" variant="outline" disabled={busy} onClick={() => void change(routine, false)}>{routine.enabled ? 'Pause' : 'Resume'}</Button>
          <Button size="sm" variant="ghost" disabled={busy} onClick={() => void change(routine, true)}>Delete routine</Button>
        </div>
      </li>)}</ul>}
  </section>
}
