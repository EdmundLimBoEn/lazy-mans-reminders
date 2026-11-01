import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { ConnectedAgents } from './ConnectedAgents'

// Retain hook state while exercising the component's real handlers and rendered output.
const hooks = vi.hoisted(() => ({
  states: [] as unknown[], cursor: 0,
  effect: undefined as undefined | (() => void | (() => void)),
}))
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

type Props = { children?: ReactNode; onClick?: () => void; disabled?: boolean; role?: string }
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
function render(token = 'token') {
  hooks.cursor = 0
  return nodes(ConnectedAgents({ accessToken: token }))
}
function names() {
  return render().filter(node => node.type === 'strong').map(node => node.props.children)
}
function error() {
  return render().find(node => node.props.role === 'alert')?.props.children
}
function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason: Error) => void
  const promise = new Promise<T>((done, fail) => { resolve = done; reject = fail })
  return { promise, resolve, reject }
}
const agent = { id: 'grant-123', clientName: 'Test agent' }
const response = (grants: unknown[], status = 200) => new Response(JSON.stringify({ grants }), { status })
let fetchMock: ReturnType<typeof vi.fn>

beforeEach(async () => {
  hooks.states = []
  fetchMock = vi.fn().mockResolvedValue(response([agent]))
  vi.stubGlobal('fetch', fetchMock)
  render()
  hooks.effect!()
  await vi.waitFor(() => expect(names()).toEqual(['Test agent']))
})
afterEach(() => vi.unstubAllGlobals())

it.each(['success', 'http error', 'rejection'])('ignores a token-refresh read returning %s after revocation reconciliation', async outcome => {
  const stale = deferred<Response>()
  fetchMock.mockReturnValueOnce(stale.promise)
  render('refreshed-token')
  hooks.effect!()
  fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }))
  fetchMock.mockResolvedValueOnce(response([]))
  render('refreshed-token').find(node => node.props.onClick)!.props.onClick!()
  await vi.waitFor(() => expect(names()).toEqual([]))
  if (outcome === 'rejection') stale.reject(new Error('Offline'))
  else stale.resolve(response([agent], outcome === 'http error' ? 500 : 200))
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(names()).toEqual([])
  expect(error()).toBeUndefined()
  expect(fetchMock).toHaveBeenCalledTimes(4)
})

it('invalidates pending reads as soon as revocation begins', async () => {
  const stale = deferred<Response>()
  const revoke = deferred<Response>()
  fetchMock.mockReturnValueOnce(stale.promise)
  render('refreshed-token')
  hooks.effect!()
  fetchMock.mockReturnValueOnce(revoke.promise)
  render().find(node => node.props.onClick)!.props.onClick!()
  stale.resolve(response([{ ...agent, clientName: 'Stale name' }]))
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(names()).toEqual(['Test agent'])
  revoke.resolve(new Response(null, { status: 500 }))
  await vi.waitFor(() => expect(error()).toBe('Could not revoke that agent.'))
  expect(render().find(node => node.props.onClick)!.props.disabled).toBe(false)
})

it('keeps the latest token-refresh result when reads finish out of order', async () => {
  const stale = deferred<Response>()
  fetchMock.mockReturnValueOnce(stale.promise)
  render('token-2')
  hooks.effect!()
  fetchMock.mockResolvedValueOnce(response([]))
  render('token-3')
  hooks.effect!()
  await vi.waitFor(() => expect(names()).toEqual([]))
  stale.resolve(response([agent]))
  await new Promise(resolve => setTimeout(resolve, 0))
  expect(names()).toEqual([])
})
