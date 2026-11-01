import { OAuthError } from '@cloudflare/workers-oauth-provider'

export type CodeClaim = { key?: string; attempt?: string }

type Operation = {
  method: 'get' | 'put' | 'delete'
  key: string
  value?: string
  options?: KVNamespacePutOptions
  codeAttempt?: string
}

function grantKey(key: string): string | null {
  const parts = key.split(':')
  if ((parts[0] === 'grant' && parts.length === 3) || (parts[0] === 'token' && parts.length === 4)) {
    return `grant:${parts[1]}:${parts[2]}`
  }
  return null
}

/** Serializes provider storage operations for one grant, including its access tokens. */
export class GrantState implements DurableObject {
  constructor(private readonly state: DurableObjectState, private readonly env: Env) {}

  async fetch(request: Request): Promise<Response> {
    const operation = await request.json<Operation>()
    // KV I/O yields to other requests unless explicitly gated. Keep the revocation
    // check and the write in the same gate so a paused write cannot restore a grant.
    return this.state.blockConcurrencyWhile(async () => {
      const { method, key, value, options } = operation
      if (method === 'delete') {
        if (key === grantKey(key)) {
          // Never expire this marker: legacy grants can have unlimited lifetimes,
          // and KV can still return records cached before deletion.
          await this.state.storage.put('revoked', true)
        }
        await this.env.OAUTH_KV.delete(key)
        return new Response(null, { status: 204 })
      }
      if (await this.state.storage.get('revoked')) {
        return method === 'get' ? Response.json(null) : new Response(null, { status: 409 })
      }
      if (method === 'get') return Response.json(await this.env.OAUTH_KV.get(key))
      try {
        await this.env.OAUTH_KV.put(key, value!, options)
      } catch (error) {
        // Only an explicit rejection of the first issuance write is safe to
        // retry. Transport failures may have committed; later writes may leave
        // credentials persisted. Neither may reopen the code.
        if (operation.codeAttempt && key === grantKey(key) && error instanceof Error &&
            /429 Too Many Requests/i.test(error.message)) {
          const id = this.env.AUTHORIZATION_STATE.idFromName(`code:${key.slice('grant:'.length)}`)
          const released = await this.env.AUTHORIZATION_STATE.get(id).fetch('https://authorization-state/release', {
            method: 'POST', body: JSON.stringify({ attempt: operation.codeAttempt }),
          })
          if (!released.ok) throw new Error('Grant state unavailable')
          return new Response(null, { status: 429 })
        }
        throw error
      }
      return new Response(null, { status: 204 })
    })
  }
}

/** Leave client records/listing in KV, but gate every grant/token read and mutation. */
export function grantStorage(env: Env, claim: CodeClaim = {}): KVNamespace {
  const kv = env.OAUTH_KV
  async function call(operation: Operation): Promise<Response> {
    const id = env.GRANT_STATE.idFromName(grantKey(operation.key)!)
    const response = await env.GRANT_STATE.get(id).fetch('https://grant-state/storage', {
      method: 'POST', body: JSON.stringify(operation),
    })
    if (response.status === 429) throw new OAuthError('temporarily_unavailable', {
      description: 'Token issuance is temporarily unavailable; retry shortly',
      statusCode: 429,
      headers: { 'Retry-After': '30' },
    })
    if (response.status === 409) throw new OAuthError('invalid_grant', { description: 'Grant not found' })
    if (!response.ok) throw new Error('Grant state unavailable')
    return response
  }
  // Only the string/json KV operations used by the locked OAuth provider are
  // adapted. Binding the remaining methods preserves the native KV receiver.
  return new Proxy(kv, {
    get(target, property) {
      if (property === 'get') return async (key: string, options?: string | { type?: string }) => {
        if (!grantKey(key)) return kv.get(key, options as 'text')
        const value = await (await call({ method: 'get', key })).json<string | null>()
        const type = typeof options === 'string' ? options : options?.type
        return value !== null && type === 'json' ? JSON.parse(value) : value
      }
      if (property === 'put') return async (key: string, value: string, options?: KVNamespacePutOptions) => {
        if (!grantKey(key)) return kv.put(key, value, options)
        const codeAttempt = key === claim.key ? claim.attempt : undefined
        if (codeAttempt) claim.attempt = undefined
        await call({ method: 'put', key, value, options, codeAttempt })
      }
      if (property === 'delete') return async (key: string) => {
        if (!grantKey(key)) return kv.delete(key)
        await call({ method: 'delete', key })
      }
      const value = Reflect.get(target, property)
      return typeof value === 'function' ? value.bind(target) : value
    },
  })
}
