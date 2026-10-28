import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'

// Run the real Board handlers with retained hooks and controllable database reads.
const hooks = vi.hoisted(() => ({ effects: [] as (() => void | (() => void))[], states: [] as unknown[], cursor: 0, load: undefined as undefined | (() => Promise<void>) }))
const db = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn(), update: vi.fn(), delete: vi.fn(), channel: vi.fn(), removeChannel: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('@dnd-kit/core', async (original) => ({
  ...await original<typeof import('@dnd-kit/core')>(),
  useSensor: () => null, useSensors: () => [],
}))
vi.mock('react', async (original) => ({
  ...await original<typeof import('react')>(),
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = initial
    return [hooks.states[index], (value: unknown) => {
      hooks.states[index] = typeof value === 'function' ? value(hooks.states[index]) : value
    }]
  },
  useRef: (current: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = { current }
    return hooks.states[index]
  },
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: () => Promise<void>) => { hooks.load = callback; return callback },
  useEffect: (effect: () => void | (() => void)) => { hooks.effects.push(effect) },
}))

type Props = {
  disabled?: boolean; value?: string; children?: ReactNode; session?: Session; 'aria-label'?: string; text?: string; id?: string
  onClick?: () => void
  onChange?: (event: { target: { value: string } }) => void
  onSubmit?: (event: { preventDefault(): void }) => void
}
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
let board: ReactElement<Props>
function render() {
  hooks.cursor = 0
  hooks.effects = []
  return nodes((board.type as (props: Props) => ReactNode)(board.props))
}
function control(label: string) {
  return render().find(node => node.props['aria-label'] === label)!.props
}
function displayed() {
  return render().filter(node => node.props.id && node.props.text).map(node => node.props.text)
}
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(done => { resolve = done })
  return { promise, resolve }
}
const original = { id: 'note', user_id: 'user', text: 'Original', sort_order: 0, is_done: false, created_at: '2026-01-01' }
type Row = typeof original
type Result = { data: Row[]; error: null }
let stored: Row[]
let reads: ReturnType<typeof deferred<Result>>[]
let write: ReturnType<typeof deferred<{ error: { message: string } | null }>>

beforeEach(async () => {
  vi.clearAllMocks()
  vi.stubGlobal('window', { location: { pathname: '/' }, clearTimeout })
  hooks.states = ['/', { user: { id: 'user' } }, true, '', false]
  hooks.cursor = 0
  board = nodes(App()).find(node => node.props.session)!
  hooks.states = []
  stored = [{ ...original }]
  reads = []
  write = deferred()
  db.rpc.mockResolvedValue({ error: null })
  db.from.mockImplementation((table: string) => {
    const query = {
      select: () => query, eq: () => query, order: () => query,
      maybeSingle: async () => ({ data: { max_lines: 6 }, error: null }),
      then: (resolve: (result: Result) => void) => {
        const pending = reads.shift()
        return (pending ? pending.promise : Promise.resolve({ data: stored.map(row => ({ ...row })), error: null })).then(resolve)
      },
      update: (changes: unknown) => { db.update(changes); return mutation },
      delete: () => { db.delete(); return mutation }, insert: () => write.promise,
    }
    const mutation = { eq: () => mutation, then: write.promise.then.bind(write.promise) }
    expect(['reminders', 'lock_screen_prefs']).toContain(table)
    return query
  })
  render()
  await hooks.load!()
})

function mutate(operation: string) {
  if (operation === 'edit') {
    control('Edit "Original"').onClick!()
    control('Edit reminder: Original').onChange!({ target: { value: 'Updated' } })
    render().find(node => node.type === 'form' && nodes(node).some(child => child.props['aria-label'] === 'Save reminder'))!.props.onSubmit!({ preventDefault() {} })
    return [{ ...original, text: 'Updated' }]
  }
  if (operation === 'add') {
    control('New reminder').onChange!({ target: { value: 'New' } })
    render().find(node => node.type === 'form')!.props.onSubmit!({ preventDefault() {} })
    return [original, { ...original, id: 'new', text: 'New', sort_order: 1 }]
  }
  control(`${operation === 'delete' ? 'Delete' : 'Complete'} "Original"`).onClick!()
  return operation === 'delete' ? [] : [{ ...original, is_done: true }]
}

it.each(['edit', 'complete', 'delete', 'add'])('%s invalidates pre-write reads and reconciles without realtime', async operation => {
  const stale = deferred<Result>()
  reads.push(stale)
  const loading = hooks.load!()
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  const acknowledged = mutate(operation)
  stale.resolve({ data: [original], error: null })
  await loading
  if (operation === 'edit') expect(displayed()).toEqual(['Updated'])
  if (operation === 'delete') expect(displayed()).toEqual([])
  if (operation === 'complete') expect(control('Mark "Original" active')).toBeDefined()
  stored = acknowledged
  write.resolve({ error: null })
  await vi.waitFor(() => expect(db.rpc).toHaveBeenCalledTimes(3))
  await vi.waitFor(() => expect(displayed()).toEqual(acknowledged.map(row => row.text)))
})

it.each(['before', 'after'])('reconciles a read started during an edit that returns %s acknowledgment', async timing => {
  const acknowledged = mutate('edit')
  const stale = deferred<Result>()
  reads.push(stale)
  const loading = hooks.load!()
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  if (timing === 'before') {
    stale.resolve({ data: [original], error: null })
    await loading
  }
  stored = acknowledged
  write.resolve({ error: null })
  await vi.waitFor(() => expect(db.rpc).toHaveBeenCalledTimes(3))
  await vi.waitFor(() => expect(displayed()).toEqual(['Updated']))
  stale.resolve({ data: [original], error: null })
  await loading
  expect(displayed()).toEqual(['Updated'])
})

it('reloads persisted state when an optimistic deletion fails', async () => {
  mutate('delete')
  expect(displayed()).toEqual([])
  write.resolve({ error: { message: 'Write failed' } })
  await vi.waitFor(() => expect(displayed()).toEqual(['Original']))
})

function editForm() {
  return render().find(node => node.type === 'form' && nodes(node).some(child => child.props['aria-label'] === 'Save reminder'))!.props
}

it('blocks overlapping saves synchronously and allows a newer edit only after acknowledgment', async () => {
  const complete = control('Complete "Original"').onClick!
  const remove = control('Delete "Original"').onClick!
  control('Edit "Original"').onClick!()
  control('Edit reminder: Original').onChange!({ target: { value: 'A' } })
  const submit = editForm().onSubmit!
  submit({ preventDefault() {} })
  // Reuse the pre-render handler: disabled state alone cannot guard this race.
  submit({ preventDefault() {} })
  complete()
  remove()
  expect(db.update).toHaveBeenCalledTimes(1)
  expect(db.delete).not.toHaveBeenCalled()
  expect(control('Edit reminder: A').disabled).toBe(true)
  expect(control('Edit reminder: A').value).toBe('A')
  expect(control('Save reminder').disabled).toBe(true)
  expect(control('Cancel editing').disabled).toBe(true)
  expect(control('Complete "A"').disabled).toBe(true)

  stored = [{ ...original, text: 'A' }]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Edit "A"')).toBeDefined())
  expect(control('Edit "A"').disabled).toBe(false)
  write = deferred()
  control('Edit "A"').onClick!()
  control('Edit reminder: A').onChange!({ target: { value: 'B' } })
  editForm().onSubmit!({ preventDefault() {} })
  expect(db.update.mock.calls).toEqual([[{ text: 'A' }], [{ text: 'B' }]])
  stored = [{ ...original, text: 'B' }]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Edit "B"')).toBeDefined())
  expect(displayed()).toEqual(['B'])
})

it('retains a failed edit draft and releases the guard for retry', async () => {
  mutate('edit')
  write.resolve({ error: { message: 'Write failed' } })
  await vi.waitFor(() => expect(control('Save reminder').disabled).toBe(false))
  expect(control('Edit reminder: Original').value).toBe('Updated')
  write = deferred()
  editForm().onSubmit!({ preventDefault() {} })
  expect(db.update).toHaveBeenCalledTimes(2)
  stored = [{ ...original, text: 'Updated' }]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Edit "Updated"')).toBeDefined())
})

function subscribeToCapacity() {
  const subscriptions: { filter: { table: string; filter: string }; callback: (payload: { new: Record<string, unknown> }) => void }[] = []
  const channel = {
    on: (_event: string, filter: typeof subscriptions[number]['filter'], callback: typeof subscriptions[number]['callback']) => {
      subscriptions.push({ filter, callback })
      return channel
    },
    subscribe: () => channel,
  }
  db.channel.mockReturnValue(channel)
  render()
  const cleanups = hooks.effects.map(effect => effect())
  const prefs = subscriptions.find(item => item.filter.table === 'lock_screen_prefs')
  expect(prefs?.filter.filter).toBe('user_id=eq.user')
  return { emit: (max_lines: number, user_id = 'user') => prefs!.callback({ new: { user_id, max_lines } }),
    cleanup: () => cleanups.forEach(cleanup => cleanup?.()), channel }
}

it('updates input and Add capacity after phone preference inserts/updates without a reminder change', async () => {
  stored = Array.from({ length: 6 }, (_, index) => ({ ...original, id: String(index) }))
  await hooks.load!()
  expect(control('New reminder').disabled).toBe(true)
  const subscription = subscribeToCapacity()
  await vi.waitFor(() => expect(db.rpc).toHaveBeenCalledTimes(3))
  const readsBefore = db.from.mock.calls.length
  subscription.emit(8)
  expect(control('New reminder').disabled).toBe(false)
  control('New reminder').onChange!({ target: { value: 'Next' } })
  expect(render().find(node => node.type !== 'form' && node.props.children === 'Add')!.props.disabled).toBe(false)
  subscription.emit(5)
  expect(control('New reminder').disabled).toBe(true)
  subscription.emit(8, 'another-user')
  expect(control('New reminder').disabled).toBe(true)
  expect(db.from).toHaveBeenCalledTimes(readsBefore)
  subscription.cleanup()
  expect(db.removeChannel).toHaveBeenCalledWith(subscription.channel)
})

it('does not let a pending board read overwrite newer phone capacity', async () => {
  stored = Array.from({ length: 6 }, (_, index) => ({ ...original, id: String(index) }))
  await hooks.load!()
  const stale = deferred<Result>()
  reads.push(stale)
  const subscription = subscribeToCapacity()
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  subscription.emit(8)
  stale.resolve({ data: stored, error: null })
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(control('New reminder').disabled).toBe(false)
  subscription.cleanup()
})
