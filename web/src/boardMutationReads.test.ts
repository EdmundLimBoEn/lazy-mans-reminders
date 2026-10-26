import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'

// Run the real Board handlers with retained hooks and controllable database reads.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0, load: undefined as undefined | (() => Promise<void>) }))
const db = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn() }))
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
  useEffect: () => {},
}))

type Props = {
  children?: ReactNode; session?: Session; 'aria-label'?: string; text?: string; id?: string
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
      update: () => mutation, delete: () => mutation, insert: () => write.promise,
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
