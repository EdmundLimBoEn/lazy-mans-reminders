import { afterEach, describe, expect, it, vi } from 'vitest'
import { handleWorkerFetch } from './index'
import { MCP_RESOURCE } from './constants'
import { hashSecret } from './token'
import type { TokenSecret } from './domain'
import type { OAuthProviderOptions } from '@cloudflare/workers-oauth-provider'

const { from } = vi.hoisted(() => ({ from: vi.fn() }))
// Exercise the configured provider callback without requiring the Workers runtime.
vi.mock('@cloudflare/workers-oauth-provider', () => ({
  OAuthProvider: class {
    constructor(private options: OAuthProviderOptions<Env>) {}
    async fetch(request: Request, env: Env) {
      const result = await this.options.resolveExternalToken!({
        token: request.headers.get('Authorization')!.slice(7), request, env,
      })
      return Response.json(result, { status: result ? 200 : 401 })
    }
  },
  OAuthError: class extends Error {},
  getOAuthApi: vi.fn(),
}))
vi.mock('@supabase/supabase-js', () => ({ createClient: () => ({ from }) }))
vi.mock('agents/mcp/server', () => ({ createMcpHandler: vi.fn() }))
vi.mock('./server', () => ({ createServer: vi.fn() }))

afterEach(() => vi.clearAllMocks())

describe('personal-token MCP requests', () => {
  it.each(['success', 'failure'])('responds before last-used bookkeeping completes (%s)', async (outcome) => {
    const tokenId = '11111111-1111-4111-8111-111111111111'
    const userId = '22222222-2222-4222-8222-222222222222'
    const secret = 'synthetic-test-secret' as TokenSecret
    const row = {
      id: tokenId, user_id: userId, name: 'Test agent',
      token_hash: await hashSecret(secret), revoked_at: null,
    }
    let finish!: () => void
    let fail!: (error: Error) => void
    const pendingWrite = new Promise<void>((resolve, reject) => { finish = resolve; fail = reject })
    const updateEq = vi.fn(() => pendingWrite)
    const update = vi.fn(() => ({ eq: updateEq }))
    from.mockReturnValue({
      select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: row, error: null }) }) }),
      update,
    })
    const background: Promise<unknown>[] = []
    const ctx = {
      waitUntil(promise: Promise<unknown>) {
        expect(this).toBe(ctx)
        background.push(promise)
      },
    } as unknown as ExecutionContext
    const request = new Request(MCP_RESOURCE, {
      headers: { Authorization: `Bearer lmr_${tokenId}_${secret}` },
    })
    let response: Response | undefined
    const fetching = handleWorkerFetch(request, {
      WEB_ORIGINS: 'https://example.com',
      SUPABASE_URL: 'https://example.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
      MCP_RATE_LIMIT: { limit: async () => ({ success: true }) },
    } as unknown as Env, ctx, {
      verifyUser: vi.fn(), accountExists: vi.fn(async () => true),
    }).then((result) => { response = result })

    try {
      await vi.waitFor(() => expect(response?.status).toBe(200))
      expect(background).toHaveLength(1)
      expect(update).toHaveBeenCalledWith({ last_used_at: expect.any(String) })
      expect(updateEq).toHaveBeenCalledWith('id', tokenId)
      expect(await response!.json()).toEqual({
        props: { userId, tokenId, agentName: 'Test agent' },
        audience: MCP_RESOURCE,
      })
    } finally {
      if (outcome === 'failure') fail(new Error('Bookkeeping unavailable'))
      else finish()
      await fetching
      await Promise.all(background)
    }
  })
})
