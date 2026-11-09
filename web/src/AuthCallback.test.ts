import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { AuthCallback } from './AuthCallback'
import { rememberReturnTo, RETURN_TO_KEY } from './mcp'

// Keep hook state across renders and replay the effect as StrictMode does.
const hooks = vi.hoisted(() => ({
  states: [] as unknown[], cursor: 0,
  effect: undefined as undefined | (() => void | (() => void)),
}))
const auth = vi.hoisted(() => ({ exchangeCodeForSession: vi.fn(), getSession: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: { auth } }))
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
  useEffect: (effect: typeof hooks.effect) => { hooks.effect = effect },
}))

type Props = { children?: ReactNode; role?: string; href?: string }
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
function render() {
  hooks.cursor = 0
  return nodes(AuthCallback({ onNavigate: vi.fn() }))
}
function visit(path: string) {
  const url = new URL(path, 'https://np.sillyapps.co')
  vi.stubGlobal('window', { location: { href: url.href, search: url.search, origin: url.origin, pathname: url.pathname, replace } })
}
function callback(path: string) {
  hooks.states = []
  visit(path)
  render()
  hooks.effect!()
}
function replayEffect() {
  render()
  hooks.effect!()
}
function expectError(message: string, retryHref: string) {
  const output = render()
  expect(output.some(node => node.props.role === 'alert')).toBe(true)
  expect(output.some(node => node.props.children === message)).toBe(true)
  expect(output.find(node => node.type === 'a')?.props.href).toBe(retryHref)
  expect(replace).not.toHaveBeenCalled()
}
const replace = vi.fn()
let storage: Map<string, string>
beforeEach(() => {
  hooks.states = []
  vi.resetAllMocks()
  auth.exchangeCodeForSession.mockResolvedValue({ error: null })
  auth.getSession.mockResolvedValue({ data: { session: { user: { id: 'unrelated-account' } } } })
  storage = new Map()
  vi.stubGlobal('sessionStorage', {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => { storage.set(key, value) },
    removeItem: (key: string) => storage.delete(key),
  })
})
afterEach(() => vi.unstubAllGlobals())

it.each([
  ['/', 'Sign-in code expired', 'Sign-in code expired'],
  ['/connect?state=consent', 'Invalid flow state', 'Invalid flow state Start sign-in again so this callback gets a fresh verification code.'],
])('shows an exchange failure despite an unrelated session, returning to %s', async (returnTo, message, expected) => {
  auth.exchangeCodeForSession.mockResolvedValue({ error: { message } })
  callback(`/auth/callback?code=account-b&return_to=${encodeURIComponent(returnTo)}`)
  await vi.waitFor(() => expectError(expected, returnTo))
})

it.each(['success', 'failure'])('exchanges only once during effect replay while %s is pending', async outcome => {
  let finish!: (result: { error: null | { message: string } }) => void
  auth.exchangeCodeForSession.mockReturnValue(new Promise(resolve => { finish = resolve }))
  storage.set(RETURN_TO_KEY, '/connect?state=stored-consent')
  callback('/auth/callback?code=account-b&sb_flow_id=flow-b')
  replayEffect()
  expect(auth.exchangeCodeForSession).toHaveBeenCalledTimes(1)
  expect(auth.exchangeCodeForSession).toHaveBeenCalledWith('account-b', { flowId: 'flow-b' })
  expect(replace).not.toHaveBeenCalled()
  finish({ error: outcome === 'success' ? null : { message: 'Sign-in code expired' } })
  await vi.waitFor(() => {
    if (outcome === 'success') expect(replace).toHaveBeenCalledExactlyOnceWith('/connect?state=stored-consent')
    else expectError('Sign-in code expired', '/connect?state=stored-consent')
  })
  replayEffect()
  expect(auth.exchangeCodeForSession).toHaveBeenCalledTimes(1)
})

it.each([
  ['/auth/callback?code=account-b', '/'],
  ['/auth/callback?return_to=%2Fconnect%3Fstate%3Dconsent#code=account-b&sb_flow_id=flow-b', '/connect?state=consent'],
])('navigates after this callback succeeds: %s', async (path, destination) => {
  callback(path)
  await vi.waitFor(() => expect(replace).toHaveBeenCalledExactlyOnceWith(destination))
  expect(auth.exchangeCodeForSession).toHaveBeenCalledWith('account-b', path.includes('sb_flow_id') ? { flowId: 'flow-b' } : undefined)
  expect(render().some(node => node.props.role === 'alert')).toBe(false)
})

it.each([
  ['/auth/callback', 'Missing sign-in code. Start sign-in again from the board or connect link.'],
  ['/auth/callback?code=account-b&error_description=Access%20denied', 'Access denied'],
])('preserves callback validation errors: %s', (path, message) => {
  callback(path)
  expectError(message, '/')
  expect(auth.exchangeCodeForSession).not.toHaveBeenCalled()
})

it('consumes stored consent state even when the callback URL supplies the destination', async () => {
  storage.set(RETURN_TO_KEY, '/connect?state=old')
  await callback('/auth/callback?code=test&return_to=%2Fconnect%3Fstate%3Dcurrent')
  expect(replace).toHaveBeenLastCalledWith('/connect?state=current')
  expect(storage.has(RETURN_TO_KEY)).toBe(false)
  await callback('/auth/callback?code=next')
  expect(replace).toHaveBeenLastCalledWith('/')
})

it.each(['error=access_denied', ''])('consumes consent state on unsuccessful callbacks (%s)', async (query) => {
  storage.set(RETURN_TO_KEY, '/connect?state=old')
  await callback(`/auth/callback?return_to=%2Fconnect%3Fstate%3Dcurrent&${query}`)
  expect(storage.has(RETURN_TO_KEY)).toBe(false)
  expect(replace).not.toHaveBeenCalled()
})

it('clears abandoned consent state when a homepage sign-in starts', async () => {
  visit('/connect?state=abandoned')
  rememberReturnTo()
  expect(storage.get(RETURN_TO_KEY)).toBe('/connect?state=abandoned')
  visit('/')
  rememberReturnTo()
  await callback('/auth/callback?code=test')
  expect(replace).toHaveBeenCalledWith('/')
})

it('does not send a missing-code retry to a protocol-relative return_to', () => {
  callback('/auth/callback?return_to=' + encodeURIComponent('/.//evil.example/phish'))
  expectError(
    'Missing sign-in code. Start sign-in again from the board or connect link.',
    '/',
  )
})

it('does not location.replace a protocol-relative return_to after exchange', async () => {
  callback('/auth/callback?code=account-b&return_to=' + encodeURIComponent('/.//evil.example/phish'))
  await vi.waitFor(() => expect(replace).toHaveBeenCalledExactlyOnceWith('/'))
})

it('preserves the stored fallback for a consent callback without return_to', async () => {
  visit('/connect?state=current')
  rememberReturnTo()
  await callback('/auth/callback?code=test')
  expect(replace).toHaveBeenCalledWith('/connect?state=current')
  expect(storage.has(RETURN_TO_KEY)).toBe(false)
})
