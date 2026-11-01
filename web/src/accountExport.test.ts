import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'
import Board from './Board'
import type { AccountExportReminder } from './lib/accountExport'

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
  const tree = nodes(Board(board.props as Parameters<typeof Board>[0]))
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
let reminderRows: AccountExportReminder[]
let reminderCap: number
let reminderFailureOffset: number | undefined
const reminderRequests: { from: number; to: number; order?: string; userId?: string; columns?: string }[] = []
const click = vi.fn()
const createElement = vi.fn(() => ({ href: '', download: '', click }))
const createObjectURL = vi.fn<(blob: Blob) => string>(() => 'blob:export')

beforeEach(() => {
  vi.clearAllMocks()
  boardStates = []
  previousKey = undefined
  preferences = { data: { max_lines: 7 }, error: null }
  reminderRows = []
  reminderCap = 1000
  reminderFailureOffset = undefined
  reminderRequests.length = 0
  vi.stubGlobal('window', { location: { pathname: '/' } })
  vi.stubGlobal('document', { createElement })
  vi.spyOn(URL, 'createObjectURL').mockImplementation(createObjectURL)
  vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
  db.from.mockImplementation((table: string) => {
    if (table === 'reminders') {
      let order: string | undefined
      let userId: string | undefined
      let columns: string | undefined
      const read = (from = 0, to = reminderCap - 1) => {
        reminderRequests.push({ from, to, order, userId, columns })
        const rows = order === 'id' ? [...reminderRows].sort((a, b) => a.id.localeCompare(b.id)) : reminderRows
        return Promise.resolve(from === reminderFailureOffset
          ? { data: null, error: { message: 'Reminder page failed' } }
          : { data: rows.slice(from, Math.min(to + 1, from + reminderCap)), error: null })
      }
      const query = {
        select: (value: string) => { columns = value; return query },
        eq: (_column: string, value: string) => { userId = value; return query },
        order: (column: string) => { order = column; return query },
        range: read,
        then: (resolve: (result: Result) => unknown) => read().then(resolve),
      }
      return query
    }
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

function reminders(count: number): AccountExportReminder[] {
  return Array.from({ length: count }, (_, index) => ({
    id: `r${String(index).padStart(5, '0')}`,
    text: `Reminder ${index}`,
    sort_order: 0,
    is_done: index % 2 === 0,
    created_at: '2026-08-01T00:00:00Z',
  })).reverse()
}

it.each([0, 1000, 2005])('downloads all %i reminders in stable order with the existing JSON format', async (count) => {
  reminderRows = reminders(count)
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const blob = createObjectURL.mock.calls[0][0]
  const serialized = await blob.text()
  const payload = JSON.parse(serialized)
  expect(payload).toEqual({
    exported_at: expect.any(String),
    service: 'lazy-mans-reminders',
    account: { email: 'A@example.com', user_id: 'A' },
    lock_screen: { max_lines: 7 },
    reminders: [...reminderRows].reverse(),
    routine_reminders: [],
    agent_keys: [],
  })
  expect(serialized).toBe(`${JSON.stringify(payload, null, 2)}\n`)
  expect(blob.type).toBe('application/json')
  expect(reminderRequests.every(request => request.order === 'id' && request.userId === 'A'
    && request.columns === 'id, text, sort_order, is_done, created_at')).toBe(true)
  expect(reminderRequests.at(-1)?.from).toBe(count)
})

it('continues after short pages when the API cap is smaller than the requested page', async () => {
  reminderRows = reminders(8)
  reminderCap = 3
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.reminders).toEqual([...reminderRows].reverse())
  expect(reminderRequests.map(request => request.from)).toEqual([0, 3, 6, 8])
  expect(reminderRequests.every(request => request.to >= request.from)).toBe(true)
})

it('does not download partial reminders when a later page fails and allows retry', async () => {
  reminderRows = reminders(1001)
  reminderFailureOffset = 1000
  render('A').click('Download my data')
  await vi.waitFor(() => expect(render('A').download?.disabled).toBe(false))
  expect(render('A').text).toContain('Reminder page failed')
  expect(createObjectURL).not.toHaveBeenCalled()
  expect(click).not.toHaveBeenCalled()

  reminderFailureOffset = undefined
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.reminders).toEqual([...reminderRows].reverse())
})
