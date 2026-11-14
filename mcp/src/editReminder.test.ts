import { createClient } from '@supabase/supabase-js'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { CLIENT_STORAGE_ERROR, runBoardCommand } from './board'
import type { AgentSession, ReminderRow } from './domain'

const session = { userId: '11111111-1111-4111-8111-111111111111', tokenId: 'test', agentName: 'Test' } as AgentSession
const id = '22222222-2222-4222-8222-222222222222'
const original: ReminderRow & { user_id: string } = {
  id, user_id: session.userId, text: '[Test] Buy mlk', is_done: false,
  sort_order: 7, created_at: '2026-11-01T00:00:00Z', completed_at: null as string | null,
}

function setup(row = { ...original }, error?: string) {
  const fetch = vi.fn<typeof globalThis.fetch>(async (input, init) => {
    const url = new URL(String(input))
    expect(url.pathname).toBe('/rest/v1/reminders')
    expect(init?.method).toBe('PATCH')
    expect(url.searchParams.get('id')).toBe(`eq.${id}`)
    expect(url.searchParams.get('user_id')).toBe(`eq.${session.userId}`)
    expect(url.searchParams.has('is_done')).toBe(false)
    if (error) return Response.json({ message: error }, { status: 400 })
    const matches = row.id === id && row.user_id === session.userId
    if (matches) Object.assign(row, JSON.parse(init!.body as string))
    return Response.json(matches ? [row] : [])
  })
  const db = createClient('https://database.test', 'test-service-role', {
    global: { fetch }, auth: { persistSession: false, autoRefreshToken: false },
  })
  return { row, fetch, edit: (text: string, reminderId = id) => runBoardCommand(db, session, { kind: 'edit', reminderId, text }) }
}

afterEach(() => vi.restoreAllMocks())

describe('edit reminder', () => {
  it.each(['Buy milk', '[Test] Buy milk', '[Other] Buy milk', '😀'.repeat(500)])(
    'replaces trimmed visible text without adding a prefix (%s)', async (text) => {
      const { edit, fetch, row } = setup()
      const result = await edit(`  ${text}  `)
      const { user_id: _owner, ...expected } = { ...original, text }
      expect(result).toEqual({ kind: 'changed', reminder: expected })
      expect(JSON.parse(fetch.mock.calls[0][1]!.body as string)).toEqual({ text })
      expect(row).toEqual({ ...original, text })
    },
  )

  it('fixes completed text without reopening or changing its completion timestamp', async () => {
    const completed = { ...original, is_done: true, completed_at: '2026-11-02T00:00:00Z' }
    const { edit, row } = setup(completed)
    expect(await edit('[Test] Buy milk')).toMatchObject({ kind: 'changed', reminder: {
      text: '[Test] Buy milk', is_done: true, completed_at: completed.completed_at, sort_order: 7,
    } })
    expect(row.is_done).toBe(true)
  })

  it('hides other owners rows and leaves them unchanged', async () => {
    const other = { ...original, user_id: '33333333-3333-4333-8333-333333333333' }
    const { edit, row } = setup({ ...other })
    expect(await edit('Changed')).toEqual({ kind: 'not_found' })
    expect(row).toEqual(other)
  })

  it('returns not_found for a missing row', async () => {
    const { edit } = setup({ ...original, id: '33333333-3333-4333-8333-333333333333' })
    expect(await edit('Changed')).toEqual({ kind: 'not_found' })
  })

  it.each(['', 'not-a-uuid'])('rejects invalid id %j before storage', async (invalidId) => {
    const { edit, fetch } = setup()
    expect(await edit('Changed', invalidId)).toEqual({ kind: 'not_found' })
    expect(fetch).not.toHaveBeenCalled()
  })

  it.each(['', ' \n\t ', 'x'.repeat(501), '😀'.repeat(501), '[Test] ' + 'x'.repeat(494)])(
    'rejects invalid text before storage (%s)', async (text) => {
      const { edit, fetch } = setup()
      expect(await edit(text)).toEqual({ kind: 'invalid_text' })
      expect(fetch).not.toHaveBeenCalled()
    },
  )

  it.each([
    ['LMR_INVALID_TEXT', { kind: 'invalid_text' }],
    ['private storage details', { kind: 'storage', message: CLIENT_STORAGE_ERROR }],
  ])('maps storage error %s', async (error, expected) => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const { edit } = setup({ ...original }, error)
    expect(await edit('Changed')).toEqual(expected)
  })
})
