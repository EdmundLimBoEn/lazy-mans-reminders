import { afterEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { AgentAccess } from './Board'

const hooks = vi.hoisted(() => ({
  states: [] as unknown[], cursor: 0,
  effect: undefined as undefined | (() => void | (() => void)),
}))
const db = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('react', async original => ({
  ...await original<typeof import('react')>(),
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = initial
    return [hooks.states[index], (value: unknown) => { hooks.states[index] = value }]
  },
  useRef: (current: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = { current }
    return hooks.states[index]
  },
  useCallback: (callback: unknown) => callback,
  useEffect: (effect: typeof hooks.effect) => { hooks.effect = effect },
}))

type Props = {
  children?: ReactNode
  className?: string
  id?: string
  onChange?: (event: { target: { value: string } }) => void
  onSubmit?: (event: { preventDefault(): void }) => void
}
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
function render() {
  hooks.cursor = 0
  return nodes(AgentAccess({ userId: 'user', accessToken: 'token' }))
}
function names() {
  return render().filter(node => node.type === 'strong').map(node => node.props.children)
}
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(done => { resolve = done })
  return { promise, resolve }
}
type ListResult = { data: { id: string; name: string; created_at: string; last_used_at: null; revoked_at: null }[]; error: null }
const key = { id: 'k1', name: 'Cursor', created_at: '2026-01-01T00:00:00.000Z', last_used_at: null, revoked_at: null }
let lists: ReturnType<typeof deferred<ListResult>>[]

function mockFrom() {
  lists = []
  db.from.mockImplementation(() => {
    const pending = lists.shift()
    const result = pending?.promise ?? Promise.resolve({ data: [], error: null })
    const query = {
      select: () => query,
      eq: () => query,
      is: () => query,
      order: () => result,
    }
    return query
  })
}

afterEach(() => {
  hooks.states = []
  hooks.effect = undefined
})

it('ignores a stale list read after mint', async () => {
  mockFrom()
  const stale = deferred<ListResult>()
  lists.push(stale)
  render()
  hooks.effect!()

  render().find(node => node.props.id === 'agent-key-name')!.props.onChange!({ target: { value: 'Cursor' } })
  const minted = deferred<{ data: string; error: null }>()
  db.rpc.mockReturnValueOnce(minted.promise)
  render().find(node => node.props.className?.includes('agent-key-form'))!.props.onSubmit!({ preventDefault() {} })

  const refresh = deferred<ListResult>()
  lists.push(refresh)
  minted.resolve({ data: 'lmr_secret', error: null })
  refresh.resolve({ data: [key], error: null })
  await vi.waitFor(() => expect(names()).toEqual(['Cursor']))

  stale.resolve({ data: [], error: null })
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(names()).toEqual(['Cursor'])
})

it('drops a second mint while the first RPC is in flight', async () => {
  mockFrom()
  db.rpc.mockReset()
  render()
  hooks.effect!()
  render().find(node => node.props.id === 'agent-key-name')!.props.onChange!({ target: { value: 'Cursor' } })
  const minted = deferred<{ data: string; error: null }>()
  db.rpc.mockReturnValue(minted.promise)
  const submit = render().find(node => node.props.className?.includes('agent-key-form'))!.props.onSubmit!
  submit({ preventDefault() {} })
  submit({ preventDefault() {} })
  expect(db.rpc).toHaveBeenCalledTimes(1)
  expect(db.rpc).toHaveBeenCalledWith('mint_agent_token', { p_name: 'Cursor' })
  minted.resolve({ data: 'lmr_secret', error: null })
})
