import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import type { ReactElement, ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import App from './App'
import Board from './Board'
import type { AccountExportReminder } from './lib/accountExport'

// Follow the component-handler harness used by RoutineReminders.test.ts.
// Keep separate hook state for App and its account subtree, respecting React keys.
const hooks = vi.hoisted(() => ({
  states: [] as unknown[], cursor: 0, effects: [] as (() => void | (() => void))[],
}))
const db = vi.hoisted(() => ({
  from: vi.fn(), channel: vi.fn(), removeChannel: vi.fn(),
  auth: { onAuthStateChange: vi.fn() },
}))
vi.mock('./supabase', () => ({ supabase: db }))
vi.mock('./lib/connectionRefresh', () => ({
  connectionRefresh: () => ({ refresh: vi.fn(), dispose: vi.fn(), onStatus: vi.fn() }),
}))
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
  useRef: (current: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = { current }
    return hooks.states[index]
  },
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: unknown) => callback,
  useEffect: (effect: () => void | (() => void)) => { hooks.effects.push(effect) },
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
let cleanups: (() => void)[]
const authListeners = new Set<(event: string, session: Session | null) => void>()
function changeAccount(userId: string | null) {
  for (const listener of authListeners) listener(userId ? 'SIGNED_IN' : 'SIGNED_OUT', userId ? session(userId) : null)
}
function unmount() {
  for (const cleanup of cleanups) cleanup()
  cleanups = []
  previousKey = undefined
}
function render(userId: string) {
  hooks.states = ['/', session(userId), true, '', false]
  hooks.cursor = 0
  const board = nodes(App()).find(node => node.props.session)!
  const mounting = board.key !== previousKey
  if (mounting) {
    unmount()
    boardStates = []
  }
  previousKey = board.key
  hooks.states = boardStates
  hooks.cursor = 0
  hooks.effects = []
  const tree = nodes(Board(board.props as Parameters<typeof Board>[0]))
  if (mounting) {
    cleanups = hooks.effects.map(effect => effect()).filter((cleanup): cleanup is () => void => typeof cleanup === 'function')
  }
  return {
    download: tree.find(node => node.props.onClick && nodes(node).some(child => child.props.children === 'Download my data' || (Array.isArray(child.props.children) && child.props.children.includes('Download my data'))))?.props,
    click: (label: string) => tree.find(node => node.props.onClick && nodes(node).some(child =>
      child.props.children === label || (Array.isArray(child.props.children) && child.props.children.includes(label)),
    ))!.props.onClick!(),
    text: tree.map(node => node.props.children).filter(child => typeof child === 'string'),
  }
}

type Result = { data: unknown; error: { message: string } | null }
let preferences: Result | Promise<Result>
let reminderRows: AccountExportReminder[]
let reminderCap: number
let reminderFailurePage: number | undefined
let afterReminderRead: (() => void) | undefined
const reminderRequests: { after?: string; from: number; to: number; order?: string; userId?: string; columns?: string }[] = []
const click = vi.fn()
const createElement = vi.fn(() => ({ href: '', download: '', click }))
const createObjectURL = vi.fn<(blob: Blob) => string>(() => 'blob:export')

beforeEach(() => {
  vi.clearAllMocks()
  boardStates = []
  cleanups = []
  authListeners.clear()
  db.auth.onAuthStateChange.mockImplementation((listener) => {
    authListeners.add(listener)
    return { data: { subscription: { unsubscribe: () => authListeners.delete(listener) } } }
  })
  const channel = { on: vi.fn().mockReturnThis(), subscribe: vi.fn().mockReturnThis() }
  db.channel.mockReturnValue(channel)
  previousKey = undefined
  preferences = { data: { max_lines: 7 }, error: null }
  reminderRows = []
  reminderCap = 1000
  reminderFailurePage = undefined
  reminderRequests.length = 0
  afterReminderRead = undefined
  vi.stubGlobal('window', { location: { pathname: '/' }, clearTimeout })
  vi.stubGlobal('document', { createElement })
  vi.spyOn(URL, 'createObjectURL').mockImplementation(createObjectURL)
  vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {})
  db.from.mockImplementation((table: string) => {
    if (table === 'reminders') {
      let order: string | undefined
      let userId: string | undefined
      let columns: string | undefined
      let after: string | undefined
      let limit = reminderCap
      const read = (from = 0, to = limit - 1) => {
        reminderRequests.push({ after, from, to, order, userId, columns })
        const filtered = reminderRows.filter(row => after === undefined || row.id > after)
        const rows = order === 'id' ? [...filtered].sort((a, b) => a.id.localeCompare(b.id)) : filtered
        const result = reminderRequests.length === reminderFailurePage
          ? { data: null, error: { message: 'Reminder page failed' } }
          : { data: rows.slice(from, Math.min(to + 1, from + reminderCap)), error: null }
        afterReminderRead?.()
        return Promise.resolve(result)
      }
      const query = {
        select: (value: string) => { columns = value; return query },
        eq: (_column: string, value: string) => { userId = value; return query },
        order: (column: string) => { order = column; return query },
        range: read,
        gt: (column: string, value: string) => { expect(column).toBe('id'); after = value; return query },
        limit: (value: number) => { limit = value; return query },
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
  unmount()
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
  expect(reminderRequests.at(-1)?.after).toBe(count ? `r${String(count - 1).padStart(5, '0')}` : undefined)
})

it('continues after short pages when the API cap is smaller than the requested page', async () => {
  reminderRows = reminders(8)
  reminderCap = 3
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.reminders).toEqual([...reminderRows].reverse())
  expect(reminderRequests.map(request => request.after)).toEqual([undefined, 'r00002', 'r00005', 'r00007'])
  expect(reminderRequests.every(request => request.to >= request.from)).toBe(true)
})

it('does not download partial reminders when a later page fails and allows retry', async () => {
  reminderRows = reminders(1001)
  reminderFailurePage = 2
  render('A').click('Download my data')
  await vi.waitFor(() => expect(render('A').download?.disabled).toBe(false))
  expect(render('A').text).toContain('Reminder page failed')
  expect(createObjectURL).not.toHaveBeenCalled()
  expect(click).not.toHaveBeenCalled()

  reminderFailurePage = undefined
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.reminders).toEqual([...reminderRows].reverse())
})

it.each(['r00000', 'r00999'])('does not skip untouched reminders when fetched reminder %s is deleted between pages', async (deletedId) => {
  reminderRows = reminders(1002)
  const expected = [...reminderRows].reverse()
  afterReminderRead = () => {
    if (reminderRequests.length === 1) {
      reminderRows = reminderRows.filter(row => row.id !== deletedId)
    }
  }
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(reminderRows).toHaveLength(1001)
  expect(payload.reminders).toEqual(expected)
})

// Let the actual async handler (including Promise.all) settle before checking
// that cancellation produced no download.
const settleExport = () => new Promise(resolve => setTimeout(resolve, 0))

it.each([1, 2])('cancels an export when auth changes during reminder page %i', async (page) => {
  reminderRows = reminders(1002)
  afterReminderRead = () => {
    if (reminderRequests.length === page) {
      changeAccount('B')
      // Later requests are filtered for A but authorized as B, so RLS returns no rows.
      reminderRows = []
    }
  }
  render('A').click('Download my data')
  await settleExport()
  expect(createObjectURL).not.toHaveBeenCalled()
  expect(click).not.toHaveBeenCalled()
  expect(reminderRequests).toHaveLength(page)

  afterReminderRead = undefined
  render('B').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.account.user_id).toBe('B')
})

it.each(['account change', 'sign out', 'unmount'])('cancels after pagination while preferences are pending on %s', async (reason) => {
  let resolve!: (result: Result) => void
  preferences = new Promise<Result>(done => { resolve = done })
  render('A').click('Download my data')
  await settleExport()
  expect(reminderRequests).toHaveLength(1)
  if (reason === 'account change') {
    changeAccount('B')
    render('B')
  } else if (reason === 'sign out') changeAccount(null)
  else unmount()
  resolve({ data: { max_lines: 7 }, error: null })
  await settleExport()
  expect(createObjectURL).not.toHaveBeenCalled()
  expect(createElement).not.toHaveBeenCalled()
  expect(click).not.toHaveBeenCalled()
})

it('continues exporting across a token refresh for the same account', async () => {
  reminderRows = reminders(1002)
  afterReminderRead = () => {
    for (const listener of authListeners) {
      listener('TOKEN_REFRESHED', { ...session('A'), access_token: 'refreshed-token-A' })
    }
    render('A')
  }
  render('A').click('Download my data')
  await vi.waitFor(() => expect(click).toHaveBeenCalledTimes(1))
  const payload = JSON.parse(await createObjectURL.mock.calls[0][0].text())
  expect(payload.reminders).toEqual([...reminderRows].reverse())
})
