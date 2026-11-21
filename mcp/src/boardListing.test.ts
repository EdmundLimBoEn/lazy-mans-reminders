import { createClient } from '@supabase/supabase-js'
import { describe, expect, it, vi } from 'vitest'
import { CLIENT_STORAGE_ERROR, runBoardCommand } from './board'
import type { AgentSession } from './domain'

const session = { userId: 'owner', tokenId: 'token', agentName: 'Test' } as AgentSession
const makeRow = (id: number, isDone: boolean, userId = 'owner') => ({
  id: String(id).padStart(5, '0'), text: 'Reminder', is_done: isDone,
  sort_order: 0, created_at: '2026-01-01T00:00:00Z', completed_at: null, snoozed_until: null as string | null, user_id: userId,
})

function database(rows: ReturnType<typeof makeRow>[], cap: number, failure?: 'page' | 'count' | 'missing-count' | 'preferences', afterFirstPage?: () => void) {
  let pageRequests = 0
  const requests: { url: URL; method: string; headers: Headers }[] = []
  const fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input))
    const method = init?.method ?? 'GET'
    requests.push({ url, method, headers: new Headers(init?.headers) })
    if (url.pathname.endsWith('/lock_screen_prefs')) {
      if (failure === 'preferences') {
        return Response.json({ message: 'Synthetic preference failure' }, { status: 400 })
      }
      return Response.json({ max_lines: 6 })
    }
    if (method === 'GET' && pageRequests++ === 1) afterFirstPage?.()
    const params = url.searchParams
    const filtered = rows.filter(row =>
      (!params.has('user_id') || params.get('user_id') === `eq.${row.user_id}`) &&
      (!params.has('id') || row.id > params.get('id')!.slice(3)) &&
      (!params.has('is_done') || params.get('is_done') === `eq.${row.is_done}`) &&
      (!params.has('or') || row.snoozed_until === null || Date.parse(row.snoozed_until) <= Date.now()))
    const offset = Number(params.get('offset') ?? 0)
    const laterPage = offset > 0 || params.has('id')
    if ((failure === 'page' && laterPage) || (failure === 'count' && method === 'HEAD')) {
      return Response.json({ message: 'Synthetic storage failure' }, { status: 400 })
    }
    const order = (params.get('order') ?? '').split(',').map(value => value.split('.')[0])
    filtered.sort((a, b) => {
      for (const key of order) {
        const left = a[key as keyof typeof a]!
        const right = b[key as keyof typeof b]!
        if (left < right) return -1
        if (left > right) return 1
      }
      return 0
    })
    const page = filtered.slice(offset, offset + Math.min(cap, Number(params.get('limit') ?? cap)))
    const headers: Record<string, string> = failure === 'missing-count' ? {} : {
      'content-range': `${offset}-${offset + page.length - 1}/${method === 'HEAD' ? filtered.length : '*'}`,
    }
    return new Response(method === 'HEAD' ? null : JSON.stringify(page.map(({ user_id: _owner, ...row }) => row)), {
      headers: { 'content-type': 'application/json', ...headers },
    })
  })
  const client = createClient('https://database.test', 'test-only', {
    global: { fetch }, auth: { persistSession: false, autoRefreshToken: false },
  })
  return { client, requests }
}

describe('MCP reminder listing pagination', () => {
  it.each(['active', 'completed', 'all'] as const)('returns every owned %s row across a 1,000-row cap without page counts', async status => {
    const rows = [...Array.from({ length: 1001 }, (_, i) => makeRow(i, false)),
      ...Array.from({ length: 1001 }, (_, i) => makeRow(i + 1001, true)),
      makeRow(3000, false, 'other'), makeRow(3001, true, 'other')]
    // Equal sort keys and reversed IDs exercise the final deterministic tie-breaker.
    const { client, requests } = database([...rows].reverse(), 1000)
    const result = await runBoardCommand(client, session, { kind: 'list', status })
    const expected = rows.filter(row => row.user_id === 'owner' &&
      (status === 'all' || row.is_done === (status === 'completed')))
      .map(({ user_id: _owner, ...row }) => row)
    expect(result).toEqual({ kind: 'snapshot', snapshot: {
      reminders: expected, capacity: { used: 1001, maximum: 6, remaining: 0 },
    } })
    const pages = requests.filter(request => request.method === 'GET' && request.url.pathname.endsWith('/reminders'))
    expect(pages.length).toBe(status === 'all' ? 4 : 3)
    for (const { url, headers } of pages) {
      expect(url.searchParams.get('is_done')).toBe(status === 'all' ? null : `eq.${status === 'completed'}`)
      expect(url.searchParams.get('order')).toBe('id.asc')
      expect(headers.get('prefer') ?? '').not.toContain('count=exact')
    }
  })

  it.each([0, 1000, 2000])('stops at an empty page after %i rows without requesting counts', async length => {
    const rows = Array.from({ length }, (_, i) => makeRow(i, true))
    const { client, requests } = database(rows, 1000)
    expect(await runBoardCommand(client, session, { kind: 'list', status: 'completed' })).toEqual({
      kind: 'snapshot', snapshot: {
        reminders: rows.map(({ user_id: _owner, ...row }) => row),
        capacity: { used: 0, maximum: 6, remaining: 6 },
      },
    })
    const reminders = requests.filter(request => request.url.pathname.endsWith('/reminders'))
    expect(reminders.filter(request => request.method === 'GET')).toHaveLength(length / 1000 + 1)
    const counts = reminders.filter(request => request.headers.get('prefer')?.includes('count=exact'))
    expect(counts).toHaveLength(1)
    expect(counts[0].method).toBe('HEAD')
    expect(counts[0].url.searchParams.get('is_done')).toBe('eq.false')
  })

  it.each(['active', 'completed', 'all'] as const)('does not skip untouched %s rows when a fetched row is deleted', async status => {
    const rows = Array.from({ length: 1002 }, (_, i) => makeRow(i, status !== 'active'))
    const expected = rows.map(({ user_id: _owner, ...row }) => row)
    const { client } = database(rows, 1000, undefined, () => { rows.shift() })
    const result = await runBoardCommand(client, session, { kind: 'list', status })
    expect(result).toMatchObject({ kind: 'snapshot', snapshot: { reminders: expected } })
  })

  it('restores board order after traversing IDs across pages', async () => {
    const rows = [
      { ...makeRow(0, true), sort_order: -1 },
      { ...makeRow(1, false), sort_order: 2 },
      { ...makeRow(2, false), created_at: '2026-02-01T00:00:00Z' },
      makeRow(4, false), makeRow(3, false),
    ]
    const { client } = database(rows, 2)
    const result = await runBoardCommand(client, session, { kind: 'list', status: 'all' })
    expect(result.kind).toBe('snapshot')
    if (result.kind === 'snapshot') {
      expect(result.snapshot.reminders.map(row => row.id)).toEqual(['00003', '00004', '00002', '00001', '00000'])
    }
  })

  it('continues through a server cap smaller than the requested page and counts active rows independently', async () => {
    const rows = Array.from({ length: 9 }, (_, i) => makeRow(i, i >= 5))
    const { client, requests } = database(rows, 2)
    const result = await runBoardCommand(client, session, { kind: 'list', status: 'completed' })
    expect(result).toMatchObject({ kind: 'snapshot', snapshot: {
      reminders: rows.slice(5).map(({ user_id: _owner, ...row }) => row),
      capacity: { used: 5, maximum: 6, remaining: 1 },
    } })
    expect(requests.filter(r => r.url.searchParams.has('offset')).map(r => r.url.searchParams.get('id'))).toEqual([null, 'gt.00006', 'gt.00008'])
  })

  it('returns an empty completed list while retaining active capacity', async () => {
    const { client } = database([makeRow(0, false)], 1000)
    expect(await runBoardCommand(client, session, { kind: 'list', status: 'completed' })).toEqual({
      kind: 'snapshot', snapshot: { reminders: [], capacity: { used: 1, maximum: 6, remaining: 5 } },
    })
  })

  it.each(['page', 'count', 'missing-count', 'preferences'] as const)('does not report a complete snapshot after %s failure', async failure => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      const { client } = database([makeRow(0, false), makeRow(1, true), makeRow(2, true)], 1, failure)
      expect(await runBoardCommand(client, session, { kind: 'list', status: 'all' })).toEqual({
        kind: 'storage', message: CLIENT_STORAGE_ERROR,
      })
    } finally {
      spy.mockRestore()
    }
  })
})

it.each(['active', 'all'] as const)('respects snoozes in %s listing and the independent capacity count', async status => {
  const rows = [makeRow(0, false), { ...makeRow(1, false), snoozed_until: '2999-01-01T00:00:00Z' },
    { ...makeRow(2, false), snoozed_until: '2000-01-01T00:00:00Z' }, makeRow(3, true)]
  const { client, requests } = database(rows, 1)
  const result = await runBoardCommand(client, session, { kind: 'list', status })
  expect(result).toMatchObject({ kind: 'snapshot', snapshot: { capacity: { used: 2, remaining: 4 } } })
  if (result.kind !== 'snapshot') throw new Error('Expected snapshot')
  expect(result.snapshot.reminders.map(row => row.id)).toEqual(status === 'all' ? ['00000', '00001', '00002', '00003'] : ['00000', '00002'])
  if (status === 'all') expect(result.snapshot.reminders[1].snoozed_until).toBe('2999-01-01T00:00:00Z')
  const count = requests.find(request => request.method === 'HEAD')!
  expect(count.url.searchParams.get('or')).toBe('(snoozed_until.is.null,snoozed_until.lte.now)')
  for (const request of requests.filter(request => request.method === 'GET' && request.url.pathname.endsWith('/reminders'))) {
    expect(request.url.searchParams.get('select')).toContain('snoozed_until')
    expect(request.url.searchParams.get('or')).toBe(status === 'active' ? '(snoozed_until.is.null,snoozed_until.lte.now)' : null)
  }
})
