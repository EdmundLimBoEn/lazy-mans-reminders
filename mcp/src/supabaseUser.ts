import { createClient } from '@supabase/supabase-js'

export type VerifiedUser = {
  id: string
  email: string | null
  fullName: string
}

/** Resolve a token, return null for rejected credentials, or throw when verification is unavailable. */
export type VerifyUser = (env: Env, accessToken: string) => Promise<VerifiedUser | null>

/**
 * Report whether an account still exists. Resolves false when Supabase says the
 * user is gone and throws when the answer could not be obtained, so callers can
 * fail closed instead of treating an outage as a deleted account.
 */
export type AccountExists = (env: Env, userId: string) => Promise<boolean>

export type IdentityDeps = {
  verifyUser: VerifyUser
  accountExists: AccountExists
}

type FetchLike = typeof fetch

async function withAuthDeadline<T>(fetchImpl: FetchLike | undefined, request: (fetch: FetchLike) => Promise<T>): Promise<T> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 10_000)
  try {
    // Keep the deadline active until the SDK has consumed the response body.
    return await request((input, init) => (fetchImpl ?? fetch)(input, {
      ...init,
      signal: controller.signal,
    }))
  } finally {
    clearTimeout(timer)
  }
}

export function verifySupabaseUserWith(fetchImpl?: FetchLike): VerifyUser {
  return async (env, accessToken) => {
    if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY || !accessToken) return null
    const { data, error } = await withAuthDeadline(fetchImpl, async (fetch) => {
      const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { fetch },
      })
      return await supabase.auth.getUser(accessToken)
    })
    if (error) {
      if (error.status === 401 || error.status === 403) return null
      throw error
    }
    if (!data.user) return null
    const metadata = data.user.user_metadata as Record<string, unknown> | undefined
    return {
      id: data.user.id,
      email: data.user.email ?? null,
      fullName: typeof metadata?.full_name === 'string' ? metadata.full_name : '',
    }
  }
}

export function supabaseAccountExistsWith(fetchImpl?: FetchLike): AccountExists {
  return async (env, userId) => {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Supabase service role is not configured')
    }
    const { data, error } = await withAuthDeadline(fetchImpl, async (fetch) => {
      const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { fetch },
      })
      return await supabase.auth.admin.getUserById(userId)
    })
    if (error) {
      if (error.status === 404) return false
      throw error
    }
    return Boolean(data.user && data.user.id === userId)
  }
}

export function bearerToken(request: Request): string | null {
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return null
  const token = authorization.slice('Bearer '.length).trim()
  return token.length > 0 ? token : null
}

export const defaultIdentityDeps: IdentityDeps = {
  verifyUser: verifySupabaseUserWith(),
  accountExists: supabaseAccountExistsWith(),
}
