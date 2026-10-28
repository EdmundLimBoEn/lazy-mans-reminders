import { createClient } from '@supabase/supabase-js'
import { describe, expect, it, vi } from 'vitest'
import { CLIENT_STORAGE_ERROR, runBoardCommand } from './board'
import type { AgentSession } from './domain'

const session = { userId: 'owner', tokenId: 'token', agentName: 'Test' } as AgentSession
const makeRow = (id: number, isDone: boolean, userId = 'owner') => ({
  id: String(id).padStart(5, '0'), text: 'Reminder', is_done: isDone,
  sort_order: 0, created_at: '2026-01-01T00:00:00Z', completed_at: null, user_id: userId,
})

function database(rows: ReturnType<typeof makeRow>[], cap: number, failure?: 'page' | 'count' | 'empty' | 'missing-count') {
  const requests: { url: URL; method: string }[] = []
  const fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input))
    const method = init?.method ?? 'GET'
    requests.push({ url, method })
    if (url.pathname.endsWith('/lock_screen_prefs')) {
      return Response.json({ max_lines: 6 })
    }
    const params = url.searchParams
    const filtered = rows.filter(row =>
      (!params.has('user_id') || params.get('user_id') === `eq.${row.user_id}`) &&
      (!params.has('is_done') || params.get('is_done') === `eq.${row.is_done}`))
    const offset = Number(params.get('offset') ?? 0)
    if ((failure === 'page' && offset > 0) || (failure === 'count' && method === 'HEAD')) {
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
    const page = failure === 'empty' && offset > 0 ? [] :
      filtered.slice(offset, offset + Math.min(cap, Number(params.get('limit') ?? cap)))
    const headers: Record<string, string> = failure === 'missing-count' ? {} : {
      'content-range': `${offset}-${offset + page.length - 1}/${filtered.length}`,
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
  it.each(['active', 'completed', 'all'] as const)('returns every owned %s row across a 1,000-row cap', async status => {
    const rows = [makeRow(0, false), ...Array.from({ length: 1001 }, (_, i) => makeRow(i + 1, true)),
      makeRow(2000, false, 'other'), makeRow(2001, true, 'other')]
    // Equal sort keys and reversed IDs exercise the final deterministic tie-breaker.
    const { client, requests } = database([...rows].reverse(), 1000)
    const result = await runBoardCommand(client, session, { kind: 'list', status })
    const expected = rows.filter(row => row.user_id === 'owner' &&
      (status === 'all' || row.is_done === (status === 'completed')))
      .map(({ user_id: _owner, ...row }) => row)
    expect(result).toEqual({ kind: 'snapshot', snapshot: {
      reminders: expected, capacity: { used: 1, maximum: 6, remaining: 5 },
    } })
    const pages = requests.filter(request => request.method === 'GET' && request.url.pathname.endsWith('/reminders'))
    expect(pages.length).toBe(status === 'active' ? 1 : 2)
    for (const { url } of pages) {
      expect(url.searchParams.get('is_done')).toBe(status === 'all' ? null : `eq.${status === 'completed'}`)
      expect(url.searchParams.get('order')).toBe('is_done.asc,sort_order.asc,created_at.asc,id.asc')
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
    expect(requests.filter(r => r.url.searchParams.has('offset')).map(r => r.url.searchParams.get('offset'))).toEqual(['0', '2'])
  })

  it('returns an empty completed list while retaining active capacity', async () => {
    const { client } = database([makeRow(0, false)], 1000)
    expect(await runBoardCommand(client, session, { kind: 'list', status: 'completed' })).toEqual({
      kind: 'snapshot', snapshot: { reminders: [], capacity: { used: 1, maximum: 6, remaining: 5 } },
    })
  })

  it.each(['page', 'count', 'empty', 'missing-count'] as const)('does not report a complete snapshot after %s failure', async failure => {
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
