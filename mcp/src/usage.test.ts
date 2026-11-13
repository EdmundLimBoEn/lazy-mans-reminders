import { afterEach, describe, expect, it, vi } from 'vitest'
import { createClient } from '@supabase/supabase-js'
import { createServiceRoleClient } from './auth'
import { recordAgentUsage } from './usage'

vi.mock('./auth', () => ({ createServiceRoleClient: vi.fn() }))
afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers() })

describe('optional agent usage', () => {
  it('does no work by default', async () => {
    await recordAgentUsage({} as Env, 'owner', 'mcp_list')
    expect(createServiceRoleClient).not.toHaveBeenCalled()
  })

  it('sends only owner and allowlisted event, and tolerates database errors', async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(new Response('{}', { status: 503 }))
    vi.mocked(createServiceRoleClient).mockReturnValue(createClient('https://database.test', 'test-only', {
      global: { fetch }, auth: { persistSession: false, autoRefreshToken: false },
    }))
    await recordAgentUsage({ USAGE_ANALYTICS_ENABLED: 'true' } as Env, 'owner', 'agent_oauth_connected')
    expect(fetch).toHaveBeenCalledTimes(1)
    const [url, init] = fetch.mock.calls[0]
    expect(String(url)).toContain('/rpc/record_agent_usage')
    expect(JSON.parse(init!.body as string)).toEqual({ p_user_id: 'owner', p_event: 'agent_oauth_connected' })
  })

  it('aborts a stalled request after one second without rejecting', async () => {
    vi.useFakeTimers()
    const fetch = vi.fn<typeof globalThis.fetch>((_url, init) => new Promise((_resolve, reject) => {
      init!.signal!.addEventListener('abort', () => reject(new Error('aborted')))
    }))
    vi.mocked(createServiceRoleClient).mockReturnValue(createClient('https://database.test', 'test-only', {
      global: { fetch }, auth: { persistSession: false, autoRefreshToken: false },
    }))
    const pending = recordAgentUsage({ USAGE_ANALYTICS_ENABLED: 'true' } as Env, 'owner', 'mcp_list')
    await vi.advanceTimersByTimeAsync(1000)
    await expect(pending).resolves.toBeUndefined()
    expect(fetch.mock.calls[0][1]!.signal!.aborted).toBe(true)
  })
})
