import { vi } from 'vitest'
import { AuthorizationState } from '../src/authorizationState'
import { GrantState } from '../src/grantState'
import { handleWorkerFetch } from '../src/index'
import { memoryObjects } from './memoryObjects'

const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

export function setup() {
  const kv = new Map<string, string>()
  const deps = {
    verifyUser: async () => ({ id: USER, email: null, fullName: 'Test' }),
    accountExists: vi.fn(async () => true),
  }
  const env = {
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service',
    WEB_ORIGINS: 'https://np.sillyapps.co',
    AUTH_RATE_LIMIT: { limit: async () => ({ success: true }) },
    MCP_RATE_LIMIT: { limit: async () => ({ success: true }) },
    OAUTH_KV: {
      get: async (key: string, options?: string | { type: string }) => {
        const value = kv.get(key)
        const type = typeof options === 'string' ? options : options?.type
        return value === undefined ? null : type === 'json' ? JSON.parse(value) : value
      },
      put: async (key: string, value: string) => { kv.set(key, value) },
      delete: async (key: string) => { kv.delete(key) },
      list: async ({ prefix = '' }: { prefix?: string }) => ({
        keys: [...kv.keys()].filter((key) => key.startsWith(prefix)).map((name) => ({ name })),
        list_complete: true,
      }),
    },
    AUTHORIZATION_STATE: memoryObjects((state) => new AuthorizationState(state)),
  } as unknown as Env
  env.GRANT_STATE = memoryObjects((state) => new GrantState(state, env))
  const request = (host: string, path: string, init?: RequestInit) => handleWorkerFetch(
    new Request(`https://${host}${path}`, init), env,
    { waitUntil: vi.fn() } as unknown as ExecutionContext, deps,
  )
  const post = (host: string, path: string, body: unknown) => request(host, path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer test-session' },
    body: JSON.stringify(body),
  })
  return { env, request, post, deps, kv }
}
