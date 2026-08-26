import { describe, expect, it } from 'vitest'
import {
  boardErrorFromStorage,
  capacityError,
  capacityMaximumFromError,
  effectiveMaximum,
  MCP_MAX_LINES_CAP,
  POST_IT_HINT,
  prefixAgentText,
} from './board'

describe('prefixAgentText', () => {
  it('prefixes with [agentName] ', () => {
    expect(prefixAgentText({ text: '  buy milk  ', agentName: 'Codex' })).toEqual({
      kind: 'ok',
      text: '[Codex] buy milk',
    })
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

  it('clamps list capacity to the lock-screen 16 cap', () => {
    expect(effectiveMaximum(20)).toBe(MCP_MAX_LINES_CAP)
    expect(effectiveMaximum(null)).toBe(6)
    expect(effectiveMaximum(1)).toBe(1)
  })
})
