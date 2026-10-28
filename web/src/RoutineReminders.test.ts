import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { RoutineReminders } from './RoutineReminders'

// Exercise the component's real handlers with state retained between renders,
// without requiring a browser or replacing the async save/change logic.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0, load: undefined as undefined | (() => Promise<void>) }))
const db = vi.hoisted(() => ({ from: vi.fn() }))
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
  useEffect: () => {},
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
  const tree = nodes(RoutineReminders({ userId: 'user-1' }))
  return {
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
