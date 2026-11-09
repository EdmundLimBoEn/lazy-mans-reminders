import { beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import App from './App'

const hooks = vi.hoisted(() => ({
  states: [] as unknown[],
  cursor: 0,
  effects: [] as Array<() => void>,
}))
const auth = vi.hoisted(() => ({
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
}))
vi.mock('./supabase', () => ({ supabase: { auth } }))
vi.mock('react', async original => ({
  ...await original<typeof import('react')>(),
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

type Props = { children?: ReactNode; role?: string; title?: string; label?: string }
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
  vi.stubGlobal('document', { title: '' })
  vi.stubGlobal('window', {
    location: { pathname: '/', href: 'https://np.sillyapps.co/', reload: vi.fn() },
    history: { pushState: vi.fn() },
    scrollTo: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })
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
  await vi.waitFor(() => {
    const tree = render()
    expect(tree.some(node => node.props.role === 'alert' && node.props.title === 'Could not start the app')).toBe(true)
    expect(tree.some(node => node.props.children === message)).toBe(true)
    expect(tree.some(node => node.props.label === 'Loading')).toBe(false)
  })
})
