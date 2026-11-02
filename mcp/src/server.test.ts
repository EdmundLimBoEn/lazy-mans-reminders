import type { SupabaseClient } from '@supabase/supabase-js'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { CLIENT_STORAGE_ERROR, POST_IT_HINT } from './board'
import type { AgentSession } from './domain'
import { createServiceRoleClient } from './auth'
import { createServer } from './server'

const { handlers } = vi.hoisted(() => ({
  handlers: new Map<string, (args: { id: string }) => Promise<{ isError?: boolean; content: { text: string }[] }>>(),
}))
vi.mock('@modelcontextprotocol/server', () => ({
  McpServer: class {
    registerTool(name: string, _config: unknown, handler: typeof handlers extends Map<string, infer H> ? H : never) {
      handlers.set(name, handler)
    }
  },
}))
vi.mock('./auth', () => ({ createServiceRoleClient: vi.fn() }))

const session = { userId: '11111111-1111-4111-8111-111111111111', tokenId: 'test', agentName: 'Test' } as AgentSession
const id = '22222222-2222-4222-8222-222222222222'
const active = Array.from({ length: 16 }, (_, i) => ({
  id: `active-${i}`, text: `Reminder ${i}`, is_done: false,
  sort_order: i, created_at: '2026-10-28T00:00:00Z', completed_at: null,
}))
const quotaError = { message: 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.', details: '16 LMR_CAPACITY_REACHED' }

function setup(error: typeof quotaError | null = quotaError, listFails = false) {
  const changed = { ...active[0], id, is_done: false }
  const update = { update: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), select: vi.fn().mockReturnThis(), maybeSingle: vi.fn().mockResolvedValue({ data: error ? null : changed, error }) }
  const count = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), then: (resolve: (value: unknown) => unknown) => Promise.resolve({ count: active.length, error: null }).then(resolve) }
  const list = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), gt: vi.fn().mockReturnThis(), order: vi.fn().mockReturnThis(), range: vi.fn().mockResolvedValue({ data: [], error: null }).mockResolvedValueOnce({
    data: active,
    count: active.length,
    error: listFails ? { message: 'read failed' } : null,
  }) }
  const prefs = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), maybeSingle: vi.fn().mockResolvedValue({ data: { max_lines: 6 }, error: null }) }
  const rpc = vi.fn().mockReturnValue(update)
  const from = vi.fn().mockReturnValueOnce(count).mockReturnValueOnce(prefs).mockReturnValue(list)
  vi.mocked(createServiceRoleClient).mockReturnValue({ from, rpc } as unknown as SupabaseClient)
  createServer(session, {} as Env)
  return { update, count, list, from, rpc }
}

afterEach(() => vi.restoreAllMocks())

describe('reopen_reminder', () => {
  it('returns the hard quota and owner active snapshot even when the display limit is lower', async () => {
    const { update, count, list, rpc } = setup()
    const result = await handlers.get('reopen_reminder')!({ id })
    expect(result.isError).toBe(true)
    expect(JSON.parse(result.content[0].text)).toEqual({
      error: 'capacity', maxLines: 16, hint: POST_IT_HINT,
      capacity: { used: 16, maximum: 16, remaining: 0 },
      reminders: active.map(({ id, text }) => ({ id, text })),
    })
    expect(rpc).toHaveBeenCalledWith('reopen_reminder', { p_user_id: session.userId, p_reminder_id: id })
    expect(update.update).not.toHaveBeenCalled()
    expect(update.eq).not.toHaveBeenCalled()
    expect(list.eq).toHaveBeenCalledWith('user_id', session.userId)
    expect(list.eq).toHaveBeenCalledWith('is_done', false)
    expect(list.range).toHaveBeenCalledWith(0, 999)
    expect(count.select).toHaveBeenCalledWith('id', { count: 'exact', head: true })
    expect(count.eq.mock.calls).toEqual([['user_id', session.userId], ['is_done', false]])
  })

  it('retains capacity information if the snapshot cannot be read', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    setup(quotaError, true)
    const result = await handlers.get('reopen_reminder')!({ id })
    expect(JSON.parse(result.content[0].text)).toEqual({
      error: 'capacity', maxLines: 16, hint: POST_IT_HINT,
      capacity: { used: 16, maximum: 16, remaining: 0 }, reminders: [],
    })
  })

  it('keeps unrelated storage failures as storage errors', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const { from } = setup({ message: 'write failed', details: '' })
    const result = await handlers.get('reopen_reminder')!({ id })
    expect(result).toEqual({ isError: true, content: [{ type: 'text', text: CLIENT_STORAGE_ERROR }] })
    expect(from).not.toHaveBeenCalled()
  })

  it('still returns the changed reminder after successful reopening', async () => {
    setup(null)
    const result = await handlers.get('reopen_reminder')!({ id })
    expect(result.isError).toBeUndefined()
    expect(JSON.parse(result.content[0].text).reminder).toEqual({ ...active[0], id })
  })
})
