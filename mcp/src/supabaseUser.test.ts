import { describe, expect, it } from 'vitest'
import { supabaseAccountExistsWith, verifySupabaseUserWith } from './supabaseUser'

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
