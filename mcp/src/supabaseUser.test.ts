import { afterEach, describe, expect, it, vi } from 'vitest'
import { supabaseAccountExistsWith, verifySupabaseUserWith } from './supabaseUser'

import { handlePublicRequest } from './oauth'
import { checkAccount } from './accountGate'

const USER_ID = '11111111-1111-4111-8111-111111111111'
const env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
} as Env

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

describe('supabase account lookup', () => {
  it('treats 404 as deleted and any other failure as unknown', async () => {
    const exists = supabaseAccountExistsWith(async (input) => {
      const url = String(input)
      if (url.endsWith(`/admin/users/${USER_ID}`)) return json(404, { message: 'User not found' })
      return json(500, { message: 'nope' })
    })
    await expect(exists(env, USER_ID)).resolves.toBe(false)

    const down = supabaseAccountExistsWith(async () => json(503, { message: 'unavailable' }))
    await expect(down(env, USER_ID)).rejects.toThrow()
  })

  it('accepts only the matching admin user and a valid access token', async () => {
    const exists = supabaseAccountExistsWith(async () => json(200, {
      id: USER_ID,
      aud: 'authenticated',
    }))
    await expect(exists(env, USER_ID)).resolves.toBe(true)

    const mismatch = supabaseAccountExistsWith(async () => json(200, {
      id: '22222222-2222-4222-8222-222222222222',
      aud: 'authenticated',
    }))
    await expect(mismatch(env, USER_ID)).resolves.toBe(false)

    const verify = verifySupabaseUserWith(async () => json(200, {
      id: USER_ID,
      aud: 'authenticated',
      email: 'ada@example.com',
      user_metadata: { full_name: 'Ada' },
    }))
    await expect(verify(env, 'access-token')).resolves.toMatchObject({ id: USER_ID, email: 'ada@example.com' })
  })
})


afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers() })

describe('authentication deadlines', () => {
  it.each(['headers', 'body'] as const)('bounds stalled %s for both clients and permits retry', async (phase) => {
    vi.useFakeTimers()
    vi.spyOn(console, 'error').mockImplementation(() => {})
    let healthy = false
    const signals: AbortSignal[] = []
    const fetchImpl: typeof fetch = async (_input, init) => {
      if (healthy) return json(200, { id: USER_ID, aud: 'authenticated' })
      const signal = init?.signal
      if (signal) signals.push(signal)
      if (phase === 'headers') {
        return new Promise<Response>((_resolve, reject) => {
          signal?.addEventListener('abort', () => reject(signal.reason), { once: true })
        })
      }
      return new Response(new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode('{"id":'))
          signal?.addEventListener('abort', () => controller.error(signal.reason), { once: true })
        },
      }), { headers: { 'Content-Type': 'application/json' } })
    }
    const verifyUser = verifySupabaseUserWith(fetchImpl)
    const accountExists = supabaseAccountExistsWith(fetchImpl)
    let response: Response | undefined
    let account: string | undefined
    const pendingResponse = handlePublicRequest(new Request('https://lmr-mcp.edmundlim.systems/consent', {
      headers: { Authorization: 'Bearer test-session' },
    }), env, { verifyUser, accountExists }).then((value) => { response = value })
    const pendingAccount = checkAccount(env, accountExists, USER_ID).then((value) => { account = value })
    await vi.advanceTimersByTimeAsync(9_999)
    expect(response).toBeUndefined()
    expect(account).toBeUndefined()
    await vi.advanceTimersByTimeAsync(1)
    expect(response?.status).toBe(503)
    expect(await response?.json()).toEqual({ error: 'account_lookup_unavailable' })
    expect(account).toBe('unavailable')
    expect(signals).toHaveLength(2)
    expect(signals.every((signal) => signal.aborted)).toBe(true)
    await Promise.all([pendingResponse, pendingAccount])
    expect(vi.getTimerCount()).toBe(0)

    healthy = true
    await expect(verifyUser(env, 'test-session')).resolves.toMatchObject({ id: USER_ID })
    await expect(checkAccount(env, accountExists, USER_ID)).resolves.toBe('live')
    expect(vi.getTimerCount()).toBe(0)
  })

  it('clears deadlines after rejected credentials and upstream errors', async () => {
    vi.useFakeTimers()
    await expect(verifySupabaseUserWith(async () => json(401, {}))(env, 'bad-token')).resolves.toBeNull()
    await expect(supabaseAccountExistsWith(async () => json(503, {}))(env, USER_ID)).rejects.toThrow()
    expect(vi.getTimerCount()).toBe(0)
  })
})
