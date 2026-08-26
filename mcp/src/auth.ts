import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { AgentSession, TokenHash } from './domain'
import { hashSecret, parsePresentedToken, secretsEqual } from './token'

type TokenRow = {
  id: string
  user_id: string
  name: string
  token_hash: string
  revoked_at: string | null
}

export function createServiceRoleClient(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

export async function resolveSession(
  env: Env,
  authorization: string | null,
  waitUntil?: (promise: Promise<unknown>) => void,
): Promise<AgentSession | null> {
  if (!authorization?.startsWith('Bearer ')) return null
  const presented = parsePresentedToken(authorization.slice('Bearer '.length).trim())
  if (!presented) return null

  const supabase = createServiceRoleClient(env)
  const { data, error } = await supabase
    .from('agent_tokens')
    .select('id, user_id, name, token_hash, revoked_at')
    .eq('id', presented.tokenId)
    .maybeSingle()
  if (error || !data) return null

  const row = data as TokenRow
  if (row.revoked_at) return null

  const expected = row.token_hash as TokenHash
  const actual = await hashSecret(presented.secret)
  if (!secretsEqual(expected, actual)) return null

  const touch = Promise.resolve(
    supabase
      .from('agent_tokens')
      .update({ last_used_at: new Date().toISOString() })
      .eq('id', presented.tokenId)
      .then(() => undefined, () => undefined),
  )
  if (waitUntil) waitUntil(touch)
  else await touch

  return {
    userId: row.user_id as AgentSession['userId'],
    tokenId: row.id as AgentSession['tokenId'],
    agentName: row.name,
  }
}
