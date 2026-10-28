import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'

// Follow the component-handler harness used by RoutineReminders.test.ts.
// Keep separate hook state for App and its account subtree, respecting React keys.
const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0 }))
const db = vi.hoisted(() => ({
  from: vi.fn(),
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
    if (!(index in hooks.states)) hooks.states[index] = typeof initial === 'function' ? initial() : initial
    return [hooks.states[index], (value: unknown) => { hooks.states[index] = value }]
  },
  useRef: (current: unknown) => ({ current }),
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: unknown) => callback,
  useEffect: () => {},
}))

type Props = { children?: ReactNode; disabled?: boolean; onClick?: () => void; session?: Session }
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}
const session = (id: string) => ({ user: { id, email: `${id}@example.com` }, access_token: `token-${id}` }) as Session
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
  const tree = nodes((board.type as (props: Props) => ReactNode)(board.props))
  return {
    download: tree.find(node => node.props.onClick && nodes(node).some(child => child.props.children === 'Download my data' || (Array.isArray(child.props.children) && child.props.children.includes('Download my data'))))?.props,
    click: (label: string) => tree.find(node => node.props.onClick && nodes(node).some(child =>
      child.props.children === label || (Array.isArray(child.props.children) && child.props.children.includes(label)),
    ))!.props.onClick!(),
    text: tree.map(node => node.props.children).filter(child => typeof child === 'string'),
  }
}

type Result = { data: unknown; error: { message: string } | null }
let preferences: Result
const click = vi.fn()
const createElement = vi.fn(() => ({ href: '', download: '', click }))
const createObjectURL = vi.fn<(blob: Blob) => string>(() => 'blob:export')

beforeEach(() => {
  vi.clearAllMocks()
  boardStates = []
  previousKey = undefined
  preferences = { data: { max_lines: 7 }, error: null }
  vi.stubGlobal('window', { location: { pathname: '/' } })
  vi.stubGlobal('document', { createElement })
  vi.spyOn(URL, 'createObjectURL').mockImplementation(createObjectURL)
  vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
  db.from.mockImplementation((table: string) => {
    const result = table === 'lock_screen_prefs' ? preferences : { data: [], error: null }
    return {
      select: () => ({
        eq: () => Object.assign(Promise.resolve(result), {
          maybeSingle: () => Promise.resolve(result),
          is: () => Promise.resolve(result),
        }),
      }),
    }
  })
})

afterEach(() => {
  vi.restoreAllMocks()
  vi.unstubAllGlobals()
})

it('rejects a preference-only failure without downloading and permits a successful retry', async () => {
  preferences = { data: null, error: { message: 'Preference read failed' } }
  render('A').click('Download my data')
  await vi.waitFor(() => expect(render('A').download?.disabled).toBe(false))
  expect(render('A').text).toContain('Preference read failed')
  expect(db.from.mock.calls.map(([table]) => table)).toEqual([
    'reminders', 'lock_screen_prefs', 'agent_token_clients', 'routine_reminders',
  ])
  expect(createObjectURL).not.toHaveBeenCalled()
  expect(createElement).not.toHaveBeenCalled()
  expect(click).not.toHaveBeenCalled()

  preferences = { data: { max_lines: 7 }, error: null }
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  expect(render('A').download?.disabled).toBe(false)
  expect(render('A').text).not.toContain('Preference read failed')
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.lock_screen.max_lines).toBe(7)
  expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:export')
})
