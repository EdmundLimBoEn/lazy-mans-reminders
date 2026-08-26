import { describe, expect, it } from 'vitest'
import worker from './index'

const env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
} as Env

const ctx = {
  waitUntil() {},
  passThroughOnException() {},
  props: {},
} as unknown as ExecutionContext

describe('mcp worker routes', () => {
  it('serves an unauthenticated server card', async () => {
    const response = await worker.fetch(
      new Request('https://mcp.lmr.edmundlim.systems/'),
      env,
      ctx,
    )
    expect(response.status).toBe(200)
    const body = await response.json() as { url: string; tools: string[] }
    expect(body.url).toBe('/mcp')
    expect(body.tools).toContain('list_reminders')
    expect(body.tools).toContain('whoami')
  })

  it('rejects /mcp without a Bearer token', async () => {
    const response = await worker.fetch(
      new Request('https://mcp.lmr.edmundlim.systems/mcp'),
      env,
      ctx,
    )
    expect(response.status).toBe(401)
  })
})
