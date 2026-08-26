import { describe, expect, it } from 'vitest'
import {
  accountExportFilename,
  buildAccountExport,
  serializeAccountExport,
} from './accountExport'

describe('accountExportFilename', () => {
  it('uses the UTC date', () => {
    expect(accountExportFilename(new Date('2026-08-26T15:04:00Z'))).toBe(
      'lmr-account-2026-08-26.json',
    )
  })
})

describe('buildAccountExport', () => {
  it('omits token secrets and includes board data', () => {
    const payload = buildAccountExport({
      exportedAt: '2026-08-26T12:00:00.000Z',
      email: 'you@example.com',
      userId: 'user-1',
      maxLines: 6,
      reminders: [{
        id: 'r1',
        text: 'Book dentist',
        sort_order: 0,
        is_done: false,
        created_at: '2026-08-01T00:00:00Z',
      }],
      agentKeys: [{
        id: 'k1',
        name: 'Cursor',
        created_at: '2026-08-02T00:00:00Z',
        last_used_at: null,
      }],
    })
    expect(payload.service).toBe('lazy-mans-reminders')
    expect(payload.account).toEqual({ email: 'you@example.com', user_id: 'user-1' })
    expect(payload.lock_screen.max_lines).toBe(6)
    expect(payload.reminders).toHaveLength(1)
    expect(payload.agent_keys[0]).not.toHaveProperty('token')
    expect(payload.agent_keys[0]).not.toHaveProperty('token_hash')
    expect(serializeAccountExport(payload)).toContain('"Book dentist"')
  })
})
