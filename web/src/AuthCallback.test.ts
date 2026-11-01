import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { AuthCallback } from './AuthCallback'
import { rememberReturnTo, RETURN_TO_KEY } from './mcp'

const hooks = vi.hoisted(() => ({ effect: undefined as undefined | (() => void) }))
const auth = vi.hoisted(() => ({ exchangeCodeForSession: vi.fn() }))
vi.mock('./supabase', () => ({ supabase: { auth } }))
vi.mock('react', async (importOriginal) => ({
  ...await importOriginal<typeof import('react')>(),
  useState: (initial: unknown) => [initial, vi.fn()],
  useEffect: (effect: () => void) => { hooks.effect = effect },
}))

let stored: Map<string, string>
const replace = vi.fn()
function visit(path: string) {
  const url = new URL(path, 'https://lmr.sillyapps.co')
  vi.stubGlobal('window', { location: {
    href: url.href, origin: url.origin, pathname: url.pathname, search: url.search, replace,
  } })
}
async function callback(path: string) {
  visit(path)
  AuthCallback({ onNavigate: vi.fn() })
  hooks.effect!()
  await Promise.resolve()
}

beforeEach(() => {
  vi.clearAllMocks()
  auth.exchangeCodeForSession.mockResolvedValue({ error: null })
  stored = new Map()
  vi.stubGlobal('sessionStorage', {
    getItem: (key: string) => stored.get(key) ?? null,
    setItem: (key: string, value: string) => { stored.set(key, value) },
    removeItem: (key: string) => { stored.delete(key) },
  })
})
afterEach(() => vi.unstubAllGlobals())

it('consumes stored consent state even when the callback URL supplies the destination', async () => {
  stored.set(RETURN_TO_KEY, '/connect?state=old')
  await callback('/auth/callback?code=test&return_to=%2Fconnect%3Fstate%3Dcurrent')
  expect(replace).toHaveBeenLastCalledWith('/connect?state=current')
  expect(stored.has(RETURN_TO_KEY)).toBe(false)
  await callback('/auth/callback?code=next')
  expect(replace).toHaveBeenLastCalledWith('/')
})

it.each(['error=access_denied', ''])('consumes consent state on unsuccessful callbacks (%s)', async (query) => {
  stored.set(RETURN_TO_KEY, '/connect?state=old')
  await callback(`/auth/callback?return_to=%2Fconnect%3Fstate%3Dcurrent&${query}`)
  expect(stored.has(RETURN_TO_KEY)).toBe(false)
  expect(replace).not.toHaveBeenCalled()
})

it('clears abandoned consent state when a homepage sign-in starts', async () => {
  visit('/connect?state=abandoned')
  rememberReturnTo()
  expect(stored.get(RETURN_TO_KEY)).toBe('/connect?state=abandoned')
  visit('/')
  rememberReturnTo()
  await callback('/auth/callback?code=test')
  expect(replace).toHaveBeenCalledWith('/')
})

it('preserves the stored fallback for a consent callback without return_to', async () => {
  visit('/connect?state=current')
  rememberReturnTo()
  await callback('/auth/callback?code=test')
  expect(replace).toHaveBeenCalledWith('/connect?state=current')
  expect(stored.has(RETURN_TO_KEY)).toBe(false)
})
