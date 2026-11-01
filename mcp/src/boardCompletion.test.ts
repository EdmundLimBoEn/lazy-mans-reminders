import { createClient } from '@supabase/supabase-js'
import { describe, expect, it, vi } from 'vitest'
import { CLIENT_STORAGE_ERROR, runBoardCommand } from './board'
import type { AgentSession } from './domain'

const session = { userId: 'owner', tokenId: 'token', agentName: 'Test' } as AgentSession
const id = '00000000-0000-0000-0000-000000000011'

function database(isDone: boolean, budget: number, owner = 'owner', readFails = false) {
  const row = { id, text: 'Reminder', is_done: isDone, sort_order: 0,
    created_at: '2026-01-01T00:00:00Z', completed_at: isDone ? '2026-01-02T00:00:00Z' : null }
  let writes = 0
  const client = createClient('https://database.test', 'test-only', {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: async (input, init) => {
      const params = new URL(String(input)).searchParams
      if (init?.method === 'GET' && readFails) {
        return Response.json({ message: 'Synthetic read failure' }, { status: 500 })
      }
      const matches = (!params.has('id') || params.get('id') === `eq.${id}`) &&
        (!params.has('user_id') || params.get('user_id') === `eq.${owner}`) &&
        (!params.has('is_done') || params.get('is_done') === `eq.${row.is_done}`)
      if (matches && init?.method === 'PATCH') {
        if (writes >= budget) return Response.json({ message: 'rate_limited' }, { status: 400 })
        writes++
        Object.assign(row, JSON.parse(String(init.body)), { completed_at: '2026-01-03T00:00:00Z' })
      }
      // PostgREST returns an object for PATCH maybeSingle, an array for GET.
      return Response.json(init?.method === 'PATCH' ? (matches ? row : null) : (matches ? [row] : []))
    } },
  })
  return { client, row, writes: () => writes }
}

const complete = (client: ReturnType<typeof database>['client'], reminderId = id) =>
  runBoardCommand(client, session, { kind: 'complete', reminderId })

describe('completion write budget', () => {
  it('completes once, then succeeds repeatedly with the exhausted budget and original timestamp', async () => {
    const db = database(false, 1)
    const first = await complete(db.client)
    expect(first).toEqual({ kind: 'changed', reminder: { ...db.row, is_done: true } })
    for (let i = 0; i < 3; i++) expect(await complete(db.client)).toEqual(first)
    expect(db.writes()).toBe(1)
  })

  it('acknowledges an already completed reminder with no budget available', async () => {
    const db = database(true, 0)
    expect(await complete(db.client)).toEqual({ kind: 'changed', reminder: db.row })
    expect(db.writes()).toBe(0)
  })

  it.each(['other-owner', 'missing-id'])('does not acknowledge a %s reminder', async scenario => {
    const db = database(true, 0, scenario === 'other-owner' ? 'other' : 'owner')
    expect(await complete(db.client, scenario === 'missing-id' ? id.replace(/11$/, '12') : id))
      .toEqual({ kind: 'not_found' })
    expect(db.writes()).toBe(0)
  })

  it('reports a failed fallback read instead of acknowledging completion', async () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      const db = database(true, 0, 'owner', true)
      expect(await complete(db.client)).toEqual({ kind: 'storage', message: CLIENT_STORAGE_ERROR })
    } finally { spy.mockRestore() }
  })
})
