import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { RoutineReminders } from './RoutineReminders'

// Exercise the component's real handlers with state retained between renders,
// without requiring a browser or replacing the async save/change logic.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0, effects: [] as Array<() => void | (() => void)>, load: undefined as undefined | (() => Promise<void>) }))
const db = vi.hoisted(() => ({ channel: vi.fn(), removeChannel: vi.fn(), from: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('react', async (importOriginal) => ({
  ...await importOriginal<typeof import('react')>(),
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = typeof initial === 'function' ? initial() : initial
    return [hooks.states[index], (value: unknown) => { hooks.states[index] = value }]
  },
  useCallback: (callback: () => Promise<void>) => { hooks.load = callback; return callback },
  useRef: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = { current: initial }
    return hooks.states[index]
  },
  useEffect: (effect: () => void | (() => void)) => { hooks.effects.push(effect) },
  useMemo: (calculate: () => unknown, dependencies: unknown[]) => {
    const index = hooks.cursor++
    const previous = hooks.states[index] as { dependencies: unknown[]; value: unknown } | undefined
    if (!previous || dependencies.some((value, i) => !Object.is(value, previous.dependencies[i]))) {
      hooks.states[index] = { dependencies, value: calculate() }
    }
    return (hooks.states[index] as { value: unknown }).value
  },
}))

const routine = {
  id: 'routine-1', text: 'Original', interval_days: 7, start_date: '2026-10-19',
  local_time: '19:00', timezone: 'Asia/Singapore', enabled: true, next_run_at: '2026-10-26T11:00:00Z',
}

type Props = {
  children?: ReactNode; id?: string; type?: string; disabled?: boolean; value?: string; role?: string
  onSubmit: (event: { preventDefault: () => void }) => Promise<void>
  onClick: () => void
  onChange: (event: { target: { value: string } }) => void
}
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
function render() {
  hooks.cursor = 0
  hooks.effects = []
  const tree = nodes(RoutineReminders({ userId: 'user-1' }))
  return {
    tree,
    form: tree.find(node => node.type === 'form')!.props,
    text: tree.find(node => node.props.id === 'routine-text')!.props,
    change: (id: string, value: string) => {
      const event = { target: { value } }
      tree.find(node => node.props.id === id)!.props.onChange(event)
      // React change events bubble from the input/select to the form.
      tree.find(node => node.type === 'form')!.props.onChange?.(event)
    },
    button: (label: string) => tree.find(node => node.props.children === label && node.props.onClick)!.props,
    submit: tree.find(node => node.props.type === 'submit')!.props,
    alert: tree.find(node => node.props.role === 'alert')?.props.children,
  }
}

beforeEach(async () => {
  hooks.states = []
  db.from.mockReset()
  db.from.mockReturnValue({ select: () => ({ eq: () => ({ order: async () => ({ data: [routine], error: null }) }) }) })
  render()
  await hooks.load!()
  render().button('Edit').onClick()
  render().text.onChange({ target: { value: 'Keep my draft' } })
})

it('reuses saved routine content while typing and refreshes it when routine data changes', async () => {
  const routines = Array.from({ length: 50 }, (_, index) => ({ ...routine, id: `routine-${index}` }))
  const refresh = async (data: typeof routines) => {
    db.from.mockReturnValue({ select: () => ({ eq: () => ({ order: async () => ({ data, error: null }) }) }) })
    await hooks.load!()
    return render()
  }
  const format = vi.spyOn(Date.prototype, 'toLocaleString')
  try {
    const initial = await refresh(routines)
    expect(format).toHaveBeenCalledTimes(50)
    const rowContent = (view: ReturnType<typeof render>) => view.tree
      .filter(node => node.type === 'li').map(node => (node.props.children as ReactNode[])[0])
    const initialContent = rowContent(initial)
    format.mockClear()
    for (let index = 0; index < 20; index++) {
      render().change('routine-text', `Draft ${index}`)
      render().change('routine-zone', `Draft timezone ${index}`)
      const content = rowContent(render())
      content.forEach((row, i) => expect(row).toBe(initialContent[i]))
    }
    expect(format).not.toHaveBeenCalled()

    const updated = {
      ...routine, text: 'Updated routine', interval_days: 2, local_time: '08:30',
      next_run_at: '2026-11-01T08:30:00Z', timezone: 'Europe/London',
    }
    const view = await refresh([updated])
    expect(format).toHaveBeenCalledTimes(1)
    expect(format).toHaveBeenLastCalledWith(undefined, { timeZone: 'Europe/London' })
    expect(format.mock.contexts[0].toISOString()).toBe(updated.next_run_at.replace('Z', '.000Z'))
    const paragraphs = view.tree.filter(node => node.type === 'p').map(node => node.props.children)
    expect(paragraphs).toContain('Updated routine')
    expect(paragraphs).toContain('Every 2 days at 08:30 · Europe/London')
    expect(paragraphs).toContain(`Next: ${format.mock.results[0].value} · Europe/London`)
    const paused = await refresh([{ ...updated, enabled: false }])
    expect(paused.tree.some(node => node.props.children === 'Paused')).toBe(true)
    expect(format).toHaveBeenCalledTimes(1)
    const empty = await refresh([])
    expect(rowContent(empty)).toEqual([])
    expect(empty.tree.some(node => node.props.children === 'No routines yet.')).toBe(true)
  } finally {
    format.mockRestore()
  }
})

it.each(['insert', 'update'] as const)('uses the selected timezone for weekly %s start dates', async (operation) => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date('2026-10-26T01:00:00Z'))
  try {
    if (operation === 'insert') {
      render().button('Cancel edit').onClick()
      render().change('routine-text', 'Sunday reminder')
    }
    render().change('routine-weekday', '0')
    render().change('routine-time', '22:00')
    render().change('routine-zone', 'America/New_York')
    const query = { eq: vi.fn() }
    query.eq.mockReturnValueOnce(query).mockResolvedValueOnce({ error: null })
    const write = vi.fn(() => operation === 'insert' ? Promise.resolve({ error: null }) : query)
    db.from.mockReturnValueOnce({ [operation]: write })
    await render().form.onSubmit({ preventDefault() {} })
    expect(write).toHaveBeenCalledWith(expect.objectContaining({
      start_date: '2026-10-25', local_time: '22:00', timezone: 'America/New_York',
    }))
  } finally {
    vi.useRealTimers()
  }
})

it.each(['insert', 'update', 'pause', 'delete'] as const)('releases busy controls and preserves the draft when %s throws', async (operation) => {
  if (operation === 'insert') {
    render().button('Cancel edit').onClick()
    render().text.onChange({ target: { value: 'Keep my draft' } })
  }
  let reject!: (error: Error) => void
  const pending = new Promise((_, fail) => { reject = fail })
  const query = { eq: vi.fn(), insert: () => pending, update: vi.fn(), delete: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockReturnValueOnce(pending)
  query.update.mockReturnValue(query)
  query.delete.mockReturnValue(query)
  db.from.mockReturnValue(query)
  const view = render()
  const saving = operation === 'insert' || operation === 'update'
    ? view.form.onSubmit({ preventDefault() {} })
    : view.button(operation === 'pause' ? 'Pause' : 'Delete routine').onClick()
  expect(render().submit.disabled).toBe(true)
  reject(new Error('Offline'))
  await saving
  // change() is invoked by a void event handler, so drain its catch/finally.
  await Promise.resolve()
  const result = render()
  expect(result.submit.disabled).toBe(false)
  expect(result.text.value).toBe('Keep my draft')
  expect(result.alert).toBe('Offline')
  if (operation !== 'insert') expect(result.submit.children).toBe('Save routine')
})

it('releases controls and clears the saved draft if refresh throws after a save', async () => {
  const query = { eq: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockResolvedValueOnce({ error: null })
  db.from.mockReturnValueOnce({ update: () => query }).mockImplementationOnce(() => { throw new Error('Refresh failed') })
  await render().form.onSubmit({ preventDefault() {} })
  expect(render().submit.disabled).toBe(false)
  // The write succeeded, so keeping the draft would invite a duplicate insert.
  expect(render().text.value).toBe('')
  expect(render().alert).toBe('Refresh failed')
})

it('clears the draft after a successful save and refresh', async () => {
  const query = { eq: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockResolvedValueOnce({ error: null })
  db.from.mockReturnValueOnce({ update: () => query })
  await render().form.onSubmit({ preventDefault() {} })
  expect(render().submit.disabled).toBe(false)
  expect(render().text.value).toBe('')
  expect(render().submit.children).toBe('Add routine')
})

it.each(['insert', 'update'] as const)('preserves edits made during a pending %s', async (operation) => {
  if (operation === 'insert') {
    render().button('Cancel edit').onClick()
    render().change('routine-text', 'Submitted draft')
  }
  let resolve!: (result: { error: null }) => void
  const pending = new Promise<{ error: null }>(done => { resolve = done })
  const query = { eq: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockReturnValueOnce(pending)
  const write = vi.fn(() => operation === 'insert' ? pending : query)
  db.from.mockReturnValueOnce({ [operation]: write })
  const saving = render().form.onSubmit({ preventDefault() {} })
  expect(render().submit.disabled).toBe(true)
  render().change('routine-text', 'New draft while saving')
  render().change('routine-time', '20:30')
  expect(write.mock.calls[0]).toEqual([expect.objectContaining({
    text: operation === 'insert' ? 'Submitted draft' : 'Keep my draft', local_time: '19:00',
  })])
  resolve({ error: null })
  await saving
  expect(render().text.value).toBe('New draft while saving')
  expect(render().submit.disabled).toBe(false)
  expect(render().submit.children).toBe(operation === 'insert' ? 'Add routine' : 'Save routine')

  // The preserved draft remains saveable, including its schedule changes.
  const nextQuery = { eq: vi.fn() }
  nextQuery.eq.mockReturnValueOnce(nextQuery).mockResolvedValueOnce({ error: null })
  const nextWrite = vi.fn(() => operation === 'insert' ? Promise.resolve({ error: null }) : nextQuery)
  db.from.mockReturnValueOnce({ [operation]: nextWrite })
  await render().form.onSubmit({ preventDefault() {} })
  expect(nextWrite).toHaveBeenCalledWith(expect.objectContaining({ text: 'New draft while saving', local_time: '20:30' }))
  expect(render().text.value).toBe('')
})

it('preserves the draft when only its schedule changes during a save', async () => {
  let resolve!: (result: { error: null }) => void
  const pending = new Promise<{ error: null }>(done => { resolve = done })
  const query = { eq: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockReturnValueOnce(pending)
  db.from.mockReturnValueOnce({ update: () => query })
  const saving = render().form.onSubmit({ preventDefault() {} })
  render().change('routine-weekday', '3')
  resolve({ error: null })
  await saving
  expect(render().text.value).toBe('Keep my draft')
  expect(render().submit.children).toBe('Save routine')
})

it.each(['save'])('keeps the draft when %s returns a database error', async (stage) => {
  const query = { eq: vi.fn() }
  query.eq.mockReturnValueOnce(query).mockResolvedValueOnce({ error: stage === 'save' ? { message: 'Failed' } : null })
  db.from.mockReturnValueOnce({ update: () => query })
  if (stage === 'refresh') {
    db.from.mockReturnValueOnce({ select: () => ({ eq: () => ({ order: async () => ({ data: null, error: { message: 'Failed' } }) }) }) })
  }
  await render().form.onSubmit({ preventDefault() {} })
  expect(render().submit.disabled).toBe(false)
  expect(render().text.value).toBe('Keep my draft')
  expect(render().alert).toBe('Failed')
})

// Start the real subscription effect and drive recovery without row notifications.
afterEach(() => { vi.unstubAllGlobals() })
it.each(['SUBSCRIBED', 'online'])('recovers a failed read on %s and removes recovery listeners on cleanup', async trigger => {
  const browser = new EventTarget()
  vi.stubGlobal('window', browser)
  let status: ((value: string) => void) | undefined
  const channel = {
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn((callback?: (value: string) => void) => { status = callback; return channel }),
  }
  db.channel.mockReturnValue(channel)
  db.removeChannel.mockResolvedValue(undefined)
  db.from.mockImplementation(() => {
    const query = {
      select: () => query, eq: () => query, order: () => query,
      maybeSingle: async () => ({ data: null, error: null }),
      then: (resolve: (value: unknown) => void) => Promise.resolve({ data: null, error: { message: 'Offline' } }).then(resolve),
    }
    return query
  })
  render()
  const cleanup = hooks.effects.at(-1)!()
  await vi.waitFor(() => expect(db.channel).toHaveBeenCalled())
  // Let the failed initial query settle before signalling recovery.
  await new Promise(resolve => setTimeout(resolve, 0))
  const failedCalls = db.from.mock.calls.length
  db.from.mockReturnValue({ select: () => ({ eq: () => ({ order: async () => ({ data: [{ ...routine, text: 'Recovered routine' }], error: null }) }) }) })
  if (trigger === 'online') browser.dispatchEvent(new Event('online'))
  else status?.('SUBSCRIBED')
  await vi.waitFor(() => expect(db.from.mock.calls.length).toBeGreaterThan(failedCalls))
  await new Promise(resolve => setTimeout(resolve, 0))
  hooks.cursor = 0
  expect(nodes(RoutineReminders({ userId: 'user-1' })).some(node => node.props.children === 'Recovered routine')).toBe(true)
  const recoveredCalls = db.from.mock.calls.length
  status?.('CHANNEL_ERROR')
  status?.('TIMED_OUT')
  expect(db.from.mock.calls.length).toBe(recoveredCalls)
  // A later re-subscription also reloads an otherwise idle account.
  status?.('SUBSCRIBED')
  await vi.waitFor(() => expect(db.from.mock.calls.length).toBeGreaterThan(recoveredCalls))
  await new Promise(resolve => setTimeout(resolve, 0))
  if (typeof cleanup === 'function') cleanup()
  const finalCalls = db.from.mock.calls.length
  browser.dispatchEvent(new Event('online'))
  status?.('SUBSCRIBED')
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(db.from.mock.calls.length).toBe(finalCalls)
  expect(db.removeChannel).toHaveBeenCalledWith(channel)
})
