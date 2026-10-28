import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'

// Run the real Board handlers with retained hooks and controllable database reads.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0, effects: [] as Array<() => void | (() => void)>, load: undefined as undefined | (() => Promise<void>) }))
const db = vi.hoisted(() => ({ channel: vi.fn(), removeChannel: vi.fn(), from: vi.fn(), rpc: vi.fn(), update: vi.fn(), delete: vi.fn() }))
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
type Result = { data: Row[]; error: null } | { data: null; error: { message: string } }
let stored: Row[]
let reads: ReturnType<typeof deferred<Result>>[]
let write: ReturnType<typeof deferred<{ error: { message: string } | null }>>

beforeEach(async () => {
  vi.clearAllMocks()
  vi.stubGlobal('window', { location: { pathname: '/' } })
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
      maybeSingle: async () => ({ data: null, error: null }),
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

it.each(['edit', 'complete', 'delete'])('rolls back a failed %s before an unavailable recovery read', async operation => {
  const recovery = deferred<Result>()
  reads.push(recovery)
  mutate(operation)
  write.resolve({ error: { message: 'Offline write' } })
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  // Rollback must not wait for reconciliation to finish (or succeed).
  expect(displayed()).toEqual(['Original'])
  expect(control('Complete "Original"')).toBeDefined()
  recovery.resolve({ data: null, error: { message: 'Offline read' } })
  await vi.waitFor(() => expect(control('Complete "Original"').disabled).toBe(false))
  expect(displayed()).toEqual(['Original'])
  if (operation === 'edit') expect(control('Edit reminder: Original').value).toBe('Updated')

  // A subsequent mutation still works after the failed attempt releases its guard.
  write = deferred()
  control('Complete "Original"').onClick!()
  stored = [{ ...original, is_done: true }]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Mark "Original" active').disabled).toBe(false))
})

it.each(['complete', 'delete'])('failed %s rollback preserves another row’s later mutation', async operation => {
  stored.push({ ...original, id: 'other', text: 'Other', sort_order: 1 })
  await hooks.load!()
  const firstWrite = write
  mutate(operation)
  write = deferred()
  control('Complete "Other"').onClick!()
  const recovery = deferred<Result>()
  reads.push(recovery)
  firstWrite.resolve({ error: { message: 'Offline write' } })
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  expect(control('Complete "Original"')).toBeDefined()
  expect(control('Mark "Other" active')).toBeDefined()
  recovery.resolve({ data: null, error: { message: 'Offline read' } })
  await vi.waitFor(() => expect(control('Complete "Original"').disabled).toBe(false))
  stored[1].is_done = true
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Mark "Other" active').disabled).toBe(false))
})

it.each(['complete', 'delete'])('failed %s rollback preserves a newer fetched row', async operation => {
  mutate(operation)
  stored = [{ ...original, text: 'Newer' }]
  await hooks.load!()
  const recovery = deferred<Result>()
  reads.push(recovery)
  write.resolve({ error: { message: 'Write failed' } })
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  recovery.resolve({ data: null, error: { message: 'Offline read' } })
  await vi.waitFor(() => expect(control('Complete "Newer"').disabled).toBe(false))
  expect(displayed()).toEqual(['Newer'])
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

it('reopens through the owner-locked RPC and reconciles the board', async () => {
  stored = [{ ...original, is_done: true }]
  await hooks.load!()
  db.rpc.mockImplementation((name: string) => {
    if (name === 'reopen_reminder') return write.promise
    return Promise.resolve({ error: null })
  })
  control('Mark "Original" active').onClick!()
  expect(db.rpc).toHaveBeenCalledWith('reopen_reminder', {
    p_user_id: 'user', p_reminder_id: 'note', p_text: null,
  })
  expect(db.update).not.toHaveBeenCalled()
  stored = [original]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Complete "Original"').disabled).toBe(false))
})

// Start the real subscription effect and drive recovery without row notifications.
afterEach(() => { vi.unstubAllGlobals() })
it.each(['SUBSCRIBED', 'online'])('recovers a failed read on %s and removes recovery listeners on cleanup', async trigger => {
  const browser = Object.assign(new EventTarget(), { clearTimeout, setTimeout })
  vi.stubGlobal('window', browser)
  let status: ((value: string) => void) | undefined
  const channel = {
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn((callback?: (value: string) => void) => { status = callback; return channel }),
  }
  db.channel.mockReturnValue(channel)
  db.removeChannel.mockResolvedValue(undefined)
  const success = db.from.getMockImplementation()!
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
  stored = [{ ...original, text: 'Recovered board' }]
  db.from.mockImplementation(success)
  if (trigger === 'online') browser.dispatchEvent(new Event('online'))
  else status?.('SUBSCRIBED')
  await vi.waitFor(() => expect(db.from.mock.calls.length).toBeGreaterThan(failedCalls))
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(displayed()).toEqual(['Recovered board'])
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

it('rolls back a failed reopen RPC before an unavailable recovery read', async () => {
  stored = [{ ...original, is_done: true }]
  await hooks.load!()
  db.rpc.mockImplementation((name: string) => {
    if (name === 'reopen_reminder') return write.promise
    return Promise.resolve({ error: null })
  })
  const recovery = deferred<Result>()
  reads.push(recovery)
  control('Mark "Original" active').onClick!()
  expect(control('Complete "Original"').disabled).toBe(true)
  expect(db.update).not.toHaveBeenCalled()
  write.resolve({ error: { message: 'Reopen failed' } })
  await vi.waitFor(() => expect(reads).toHaveLength(0))
  expect(control('Mark "Original" active').disabled).toBe(true)
  recovery.resolve({ data: null, error: { message: 'Offline read' } })
  await vi.waitFor(() => expect(control('Mark "Original" active').disabled).toBe(false))

  write = deferred()
  control('Mark "Original" active').onClick!()
  stored = [original]
  write.resolve({ error: null })
  await vi.waitFor(() => expect(control('Complete "Original"').disabled).toBe(false))
})
