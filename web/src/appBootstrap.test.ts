import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import App, { SignIn } from './App'
import { authStorageKey } from './supabase'

const hooks = vi.hoisted(() => ({
  states: [] as unknown[],
  cursor: 0,
  effects: [] as Array<() => void>,
}))
const auth = vi.hoisted(() => ({
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
}))
vi.mock('./supabase', () => ({ authStorageKey: 'sb-test-auth-token', supabase: { auth } }))
vi.mock('react', async original => ({
  ...await original<typeof import('react')>(),
  lazy: () => () => null,
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) {
      hooks.states[index] = typeof initial === 'function' ? (initial as () => unknown)() : initial
    }
    return [hooks.states[index], (value: unknown) => { hooks.states[index] = value }]
  },
  useRef: (current: unknown) => ({ current }),
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: unknown) => callback,
  useEffect: (effect: () => void) => { hooks.effects.push(effect) },
}))

type Props = { children?: ReactNode; role?: string; title?: string; label?: string; session?: unknown }
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}

function render() {
  hooks.cursor = 0
  hooks.effects = []
  return nodes(App())
}

function start() {
  hooks.states = []
  const tree = render()
  for (const effect of hooks.effects) effect()
  return tree
}

beforeEach(() => {
  vi.stubGlobal('document', Object.assign(new EventTarget(), { title: '', visibilityState: 'visible' }))
  vi.stubGlobal('window', Object.assign(new EventTarget(), {
    location: { pathname: '/', href: 'https://np.sillyapps.co/', reload: vi.fn() },
    history: { pushState: vi.fn() },
    scrollTo: vi.fn(),
    localStorage: {},
  }))
  auth.onAuthStateChange.mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } })
})

it.each([
  ['rejects', () => auth.getSession.mockRejectedValue(
    new DOMException('The quota has been exceeded.', 'QuotaExceededError'),
  ), 'The quota has been exceeded.'],
  ['returns an error', () => auth.getSession.mockResolvedValue({
    data: { session: null }, error: { message: 'Auth session missing!' },
  }), 'Auth session missing!'],
])('shows the start-failure shell when getSession %s', async (_name, stub, message) => {
  stub()
  expect(start().some(node => node.props.label === 'Loading')).toBe(true)
  // The SDK also emits a null initial session when its storage read fails.
  auth.onAuthStateChange.mock.lastCall![0]('INITIAL_SESSION', null)
  await vi.waitFor(() => {
    const tree = render()
    expect(tree.some(node => node.props.role === 'alert' && node.props.title === 'Could not start the app')).toBe(true)
    expect(tree.some(node => node.props.children === message)).toBe(true)
    expect(tree.some(node => node.props.label === 'Loading')).toBe(false)
  })
})

it.each([
  ['#agent-access-heading', 1],
  ['', 0],
])('scrolls to Agent access on authenticated board mount for hash "%s"', async (hash, expectedScrolls) => {
  window.location.hash = hash
  const heading = { scrollIntoView: vi.fn() }
  const querySelector = (selector: string) => selector === '#agent-access-heading' ? heading : null
  Object.assign(document, { querySelector })
  auth.getSession.mockResolvedValue({ data: { session: { user: { id: 'user' } } } })
  start()
  await Promise.resolve()
  const [tree] = render()
  hooks.effects = []
  renderToStaticMarkup(tree)
  for (const effect of hooks.effects) effect()
  expect(heading.scrollIntoView).toHaveBeenCalledTimes(expectedScrolls)
})

it.each(['session removal', 'storage clear', 'return to visible tab'])(
  'unmounts the private board after %s without an auth broadcast',
  async trigger => {
    const session = { user: { id: 'user' } }
    let storedSession: typeof session | null = session
    auth.getSession.mockImplementation(async () => ({ data: { session: storedSession }, error: null }))
    start()
    await Promise.resolve()
    expect(render().some(node => node.props.session === session)).toBe(true)

    // The other tab signed out. Only the shared storage changed.
    storedSession = null
    if (trigger === 'return to visible tab') {
      document.dispatchEvent(new Event('visibilitychange'))
    } else {
      window.dispatchEvent(Object.assign(new Event('storage'), {
        key: trigger === 'storage clear' ? null : authStorageKey,
        storageArea: window.localStorage,
      }))
    }
    await Promise.resolve()
    const tree = render()
    expect(tree.some(node => node.props.session)).toBe(false)
    expect(tree.some(node => node.type === SignIn)).toBe(true)
  },
)

it('keeps the board signed out if an earlier session read finishes late', async () => {
  const session = { user: { id: 'user' } }
  let finishRead!: () => void
  auth.getSession.mockReturnValueOnce(new Promise(resolve => {
    finishRead = () => resolve({ data: { session } })
  }))
  auth.getSession.mockResolvedValue({ data: { session: null } })
  start()
  document.dispatchEvent(new Event('visibilitychange'))
  await Promise.resolve()
  finishRead()
  await Promise.resolve()
  expect(render().some(node => node.type === SignIn)).toBe(true)
})
