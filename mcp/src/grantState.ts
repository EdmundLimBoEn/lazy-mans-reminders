import { OAuthError } from '@cloudflare/workers-oauth-provider'

export type CodeClaim = { key?: string; attempt?: string }

type RefreshRecovery = {
  from: string
  to: string
  grant: string
}

type Operation = {
  method: 'get' | 'put' | 'delete'
  key: string
  value?: string
  options?: KVNamespacePutOptions
  codeAttempt?: string
  rotation?: { from?: string; to: string }
  refreshRecovery?: RefreshRecovery
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
      const revocationKey = key === grantKey(key) ? 'revoked' : `revoked:${key}`
      if (method === 'delete') {
        // Retain markers to reject stale KV records and late writes. Legacy grants
        // can live indefinitely; token keys identify individual credentials.
        await this.state.storage.put(revocationKey, true)
        if (key === grantKey(key)) await this.state.storage.delete('recoveredGrant')
        await this.env.OAUTH_KV.delete(key)
        return new Response(null, { status: 204 })
      }
      if (await this.state.storage.get('revoked') ||
          (revocationKey !== 'revoked' && await this.state.storage.get(revocationKey))) {
        return method === 'get' ? Response.json(null) : new Response(null, { status: 409 })
      }
      if (method === 'get') {
        const recovered = key === grantKey(key) ? await this.state.storage.get<string>('recoveredGrant') : undefined
        return Response.json(recovered ?? await this.env.OAUTH_KV.get(key))
      }
      let previousRefreshTokenId: string | undefined
      if (operation.rotation) {
        previousRefreshTokenId = await this.state.storage.get<string>('refreshTokenId')
        if (operation.rotation.from !== undefined) {
          // Bootstrap existing grants once. Thereafter the durable head, not a
          // possibly stale KV read, decides which refresh may commit.
          if (previousRefreshTokenId === undefined) {
            const stored = await this.env.OAUTH_KV.get(key)
            previousRefreshTokenId = stored ? JSON.parse(stored).refreshTokenId : undefined
          }
          // The provider also accepts the previous token. Reject that replay:
          // otherwise even sequential retries discard an issued successor.
          if (operation.rotation.from !== previousRefreshTokenId) return new Response(null, { status: 409 })
        }
        // Reserve the successor before KV I/O. Concurrent refreshes based on
        // the same predecessor must fail before publishing any credentials.
        await this.state.storage.put('refreshTokenId', operation.rotation.to)
      }
      try {
        await this.env.OAUTH_KV.put(key, value!, options)
      } catch (error) {
        const recovery = operation.refreshRecovery
        if (recovery && key !== grantKey(key) && error instanceof Error && /429 Too Many Requests/i.test(error.message) &&
            await this.state.storage.get<string>('refreshTokenId') === recovery.to) {
          // Restore the usable grant before reopening its generation. Keep it
          // authoritative here: an immediate KV rewrite can itself be rate limited
          // and KV reads may still return the discarded successor.
          await this.state.storage.put('recoveredGrant', recovery.grant)
          await this.state.storage.put('refreshTokenId', recovery.from)
        }
        if (operation.rotation && error instanceof Error && /429 Too Many Requests/i.test(error.message)) {
          if (previousRefreshTokenId === undefined) await this.state.storage.delete('refreshTokenId')
          else await this.state.storage.put('refreshTokenId', previousRefreshTokenId)
        }
        // An uncertain write keeps its reservation: it may have committed.
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
      if (key === grantKey(key)) await this.state.storage.delete('recoveredGrant')
      return new Response(null, { status: 204 })
    })
  }
}

/** Leave client records/listing in KV, but gate every grant/token read and mutation. */
export function grantStorage(env: Env, claim: CodeClaim = {}): KVNamespace {
  const kv = env.OAUTH_KV
  const grantReads = new Map<string, string>()
  const refreshes = new Map<string, RefreshRecovery>()
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
    if (response.status === 409) throw new OAuthError('invalid_grant', { description: 'Grant revoked or refresh token already used' })
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
        if (value !== null && key === grantKey(key)) grantReads.set(key, value)
        const type = typeof options === 'string' ? options : options?.type
        return value !== null && type === 'json' ? JSON.parse(value) : value
      }
      if (property === 'put') return async (key: string, value: string, options?: KVNamespacePutOptions) => {
        if (!grantKey(key)) return kv.put(key, value, options)
        const codeAttempt = key === claim.key ? claim.attempt : undefined
        if (codeAttempt) claim.attempt = undefined
        const grant = key === grantKey(key) ? JSON.parse(value) : undefined
        const rotation = grant?.refreshTokenId ? {
          from: grant.previousRefreshTokenId as string | undefined,
          to: grant.refreshTokenId as string,
        } : undefined
        const refreshRecovery = key !== grantKey(key) ? refreshes.get(grantKey(key)!) : undefined
        await call({ method: 'put', key, value, options, codeAttempt, rotation, refreshRecovery })
        const previous = grantReads.get(key)
        if (rotation?.from && previous) {
          // Carry this request's rotation through the provider's next token write.
          refreshes.set(key, { from: rotation.from, to: rotation.to, grant: previous })
        }
        if (refreshRecovery) refreshes.delete(grantKey(key)!)
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
