import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'
import Board from './Board'

// Follow the component-handler harness used by RoutineReminders.test.ts.
// Keep separate hook state for App and its account subtree, respecting React keys.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0 }))
const db = vi.hoisted(() => ({
  auth: { getSession: vi.fn(), signOut: vi.fn() },
  functions: { invoke: vi.fn() },
}))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('@dnd-kit/core', async (original) => ({
  ...await original<typeof import('@dnd-kit/core')>(),
  useSensor: () => null,
  useSensors: () => [],
}))
vi.mock('react', async (original) => ({
  ...await original<typeof import('react')>(),
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    const states = hooks.states
    if (!(index in states)) states[index] = typeof initial === 'function' ? initial() : initial
    return [states[index], (value: unknown) => { states[index] = value }]
  },
  useRef: (current: unknown) => ({ current }),
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: unknown) => callback,
  useEffect: () => {},
}))

type Props = { children?: ReactNode; open?: boolean; onClick?: () => void; session?: Session }
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
const session = (id: string) => ({ user: { id, email: `${id}@example.com` }, access_token: `token-${id}` }) as Session
const onAccountDeleted = vi.fn()
let boardStates: unknown[]
let previousKey: string | null | undefined
function render(userId: string) {
  hooks.states = ['/', session(userId), true, '', false]
  hooks.cursor = 0
  const board = nodes(App()).find(node => node.props.session)!
  if (board.key !== previousKey) boardStates = []
  previousKey = board.key
  hooks.states = boardStates
  hooks.cursor = 0
  const tree = nodes(Board({ ...board.props as Parameters<typeof Board>[0], onAccountDeleted }))
  return {
    open: tree.find(node => typeof node.props.open === 'boolean')!.props.open,
    click: (label: string) => tree.find(node => node.props.onClick && nodes(node).some(child =>
      child.props.children === label || (Array.isArray(child.props.children) && child.props.children.includes(label)),
    ))!.props.onClick!(),
    text: tree.map(node => node.props.children).filter(child => typeof child === 'string'),
  }
}

beforeEach(() => {
  vi.stubGlobal('window', { location: { pathname: '/' } })
  vi.clearAllMocks()
  boardStates = []
  previousKey = undefined
  db.auth.getSession.mockResolvedValue({ data: { session: session('A') }, error: null })
  db.functions.invoke.mockResolvedValue({ data: { ok: true }, error: null })
})

it('resets the open deletion confirmation on an account identity change', () => {
  render('A').click('Delete account')
  expect(render('A').open).toBe(true)
  expect(render('B').open).toBe(false)
})

it('aborts with a plain message when the session changes before confirmation', async () => {
  render('A').click('Delete account')
  db.auth.getSession.mockResolvedValue({ data: { session: session('B') }, error: null })
  render('A').click('Delete forever')
  await vi.waitFor(() => expect(render('A').text).toContain('Your signed-in account changed. Please reopen account deletion and try again.'))
  expect(db.functions.invoke).not.toHaveBeenCalled()
  expect(db.auth.signOut).not.toHaveBeenCalled()
  expect(render('A').open).toBe(false)
})

it('sends the initiating identity with a matching deletion request', async () => {
  render('A').click('Delete account')
  render('A').click('Delete forever')
  await vi.waitFor(() => expect(db.functions.invoke).toHaveBeenCalledWith('delete-account', {
    method: 'POST', body: { expectedUserId: 'A' },
  }))
})

it.each(['replacement', 'signed out', 'session error'])('ignores a delayed successful deletion after %s', async (change) => {
  let finish!: (result: { data: { ok: boolean; appleRevocation: string }; error: null }) => void
  db.functions.invoke.mockReturnValueOnce(new Promise(resolve => { finish = resolve }))
  render('A').click('Delete account')
  render('A').click('Delete forever')
  await vi.waitFor(() => expect(db.functions.invoke).toHaveBeenCalledTimes(1))

  db.auth.getSession.mockResolvedValue({
    data: { session: change === 'replacement' ? session('B') : null },
    error: change === 'session error' ? new Error('Session unavailable') : null,
  })
  if (change === 'replacement') render('B')
  finish({ data: { ok: true, appleRevocation: 'manual_required' }, error: null })
  await new Promise(resolve => setTimeout(resolve, 0))

  expect(onAccountDeleted).not.toHaveBeenCalled()
  expect(db.auth.signOut).not.toHaveBeenCalled()
})

it.each([false, true])('completes deletion for the initiating account (manual Apple revocation: %s)', async (manual) => {
  db.functions.invoke.mockResolvedValue({
    data: { ok: true, appleRevocation: manual ? 'manual_required' : 'revoked' }, error: null,
  })
  // A routine token refresh must not invalidate deletion for the same account.
  db.auth.getSession.mockResolvedValueOnce({ data: { session: session('A') }, error: null })
    .mockResolvedValue({ data: { session: { ...session('A'), access_token: 'refreshed-A' } }, error: null })
  render('A').click('Delete account')
  render('A').click('Delete forever')
  await vi.waitFor(() => expect(db.auth.signOut).toHaveBeenCalledWith({ scope: 'local' }))
  expect(onAccountDeleted).toHaveBeenCalledExactlyOnceWith(manual)
  expect(render('A').open).toBe(false)
})
