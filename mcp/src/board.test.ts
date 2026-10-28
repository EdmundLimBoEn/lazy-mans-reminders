import { describe, expect, it, vi } from 'vitest'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { AgentSession } from './domain'
import {
  boardErrorFromStorage,
  CLIENT_STORAGE_ERROR,
  capacityError,
  capacityMaximumFromError,
  effectiveMaximum,
  MCP_MAX_LINES_CAP,
  POST_IT_HINT,
  prefixAgentText,
  runBoardCommand,
} from './board'

describe('board snapshot preferences', () => {
  const session = { userId: 'owner', tokenId: 'token', agentName: 'Codex' } as AgentSession
  const reminder = {
    id: 'reminder', text: 'Book dentist', is_done: false, sort_order: 0,
    created_at: '2026-08-26T00:00:00Z', completed_at: null,
  }

  function clientWithPreferences(prefs: {
    data: { max_lines: number } | null
    error: { message: string; details: string } | null
  }): SupabaseClient {
    return {
      from(table: string) {
        const result = table === 'reminders' ? { data: [reminder], error: null, count: 1 } : prefs
        return {
          select() { return this },
          eq() { return this },
          order() { return this },
          range() { return this },
          maybeSingle() { return Promise.resolve(result) },
          then(resolve: (value: typeof result) => unknown) {
            return Promise.resolve(result).then(resolve)
          },
        }
      },
    } as unknown as SupabaseClient
  }

  it.each(['active', 'completed', 'all'] as const)(
    'rejects a %s snapshot when reminders load but preferences fail', async (status) => {
      const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
      try {
        const result = await runBoardCommand(clientWithPreferences({
          data: null, error: { message: 'Preference read failed', details: 'Storage unavailable' },
        }), session, { kind: 'list', status })
        expect(result).toEqual({ kind: 'storage', message: CLIENT_STORAGE_ERROR })
      } finally {
        spy.mockRestore()
      }
    },
  )

  it.each([
    { data: null, maximum: 6, remaining: 5 },
    { data: { max_lines: 1 }, maximum: 1, remaining: 0 },
  ])('uses capacity $maximum after a successful preference read', async ({ data, maximum, remaining }) => {
    const result = await runBoardCommand(clientWithPreferences({ data, error: null }), session, {
      kind: 'list', status: 'active',
    })
    expect(result).toEqual({
      kind: 'snapshot',
      snapshot: { reminders: [reminder], capacity: { used: 1, maximum, remaining } },
    })
  })
})

describe('prefixAgentText', () => {
  it('prefixes with [agentName] ', () => {
    expect(prefixAgentText({ text: '  buy milk  ', agentName: 'Codex' })).toEqual({
      kind: 'ok',
      text: '[Codex] buy milk',
    })
  })

  it.each([
    ['A', '😀'.repeat(251)],
    ['A', '😀'.repeat(496)],
    ['😀', 'x'.repeat(496)],
    ['', '😀'.repeat(500)],
    ['A', 'e\u0301'.repeat(248)],
  ])('accepts valid code-point lengths with agent %j', (agentName, text) => {
    expect(prefixAgentText({ text: `  ${text}  `, agentName })).toEqual({
      kind: 'ok',
      text: agentName ? `[${agentName}] ${text}` : text,
    })
  })

  it.each([
    ['A', '😀'.repeat(497)],
    ['😀', 'x'.repeat(497)],
    ['', '😀'.repeat(501)],
    ['A', 'e\u0301'.repeat(248) + 'x'],
    ['e\u0301', 'x'.repeat(496)],
  ])('rejects more than 500 code points including agent %j', (agentName, text) => {
    expect(prefixAgentText({ text, agentName })).toEqual({ kind: 'invalid_text' })
  })

  it('rejects blank text', () => {
    expect(prefixAgentText({ text: '   ', agentName: 'Codex' })).toEqual({ kind: 'invalid_text' })
  })

  it('rejects when prefix plus text exceeds 500', () => {
    expect(prefixAgentText({ text: 'x'.repeat(493), agentName: 'Codex' })).toEqual({
      kind: 'invalid_text',
    })
    expect(prefixAgentText({ text: 'x'.repeat(492), agentName: 'Codex' })).toEqual({
      kind: 'ok',
      text: `[Codex] ${'x'.repeat(492)}`,
    })
  })
})

describe('capacity mapping', () => {
  it('detects LMR_CAPACITY_REACHED and attaches the active snapshot', () => {
    expect(capacityMaximumFromError('LMR_CAPACITY_REACHED', '6')).toBe(6)
    const snapshot = {
      reminders: [{
        id: 'a',
        text: 'Book dentist',
        is_done: false,
        sort_order: 0,
        created_at: '2026-08-26T00:00:00Z',
        completed_at: null,
      }],
      capacity: { used: 6, maximum: 6, remaining: 0 },
    }
    expect(capacityError(snapshot)).toEqual({
      kind: 'capacity',
      maxLines: 6,
      hint: POST_IT_HINT,
      snapshot,
    })
  })

  it('maps invalid text exceptions without treating them as capacity', () => {
    expect(boardErrorFromStorage('LMR_INVALID_TEXT')).toEqual({ kind: 'invalid_text' })
  })

  it('returns a fixed storage error instead of the provider message', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
    const result = boardErrorFromStorage(
      'insert or update on table "reminders" violates foreign key constraint "reminders_user_id_fkey"',
      'Key (user_id)=(abc) is not present in table "users".',
    )
    expect(result).toEqual({ kind: 'storage', message: CLIENT_STORAGE_ERROR })
    expect(result.kind === 'storage' && result.message).not.toContain('foreign key')
    expect(spy).toHaveBeenCalled()
    spy.mockRestore()
  })

  it('clamps list capacity to the lock-screen 16 cap', () => {
    expect(effectiveMaximum(20)).toBe(MCP_MAX_LINES_CAP)
    expect(effectiveMaximum(null)).toBe(6)
    expect(effectiveMaximum(1)).toBe(1)
  })
})
