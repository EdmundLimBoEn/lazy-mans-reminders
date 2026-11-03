import { describe, expect, it, vi } from 'vitest'
import { memoryState } from '../test/memoryObjects'
import { GrantState, grantStorage } from './grantState'

const GRANT = 'grant:user:grant'
const TOKEN = 'token:user:grant:token'

function setup() {
  const records = new Map([[GRANT, 'grant data'], [TOKEN, 'token data']])
  const kv = {
    get: vi.fn(async (key: string) => records.get(key) ?? null),
    put: vi.fn(async (key: string, value: string) => { records.set(key, value) }),
    delete: vi.fn(async (key: string) => { records.delete(key) }),
  }
  const env = { OAUTH_KV: kv } as unknown as Env
  const state = memoryState()
  let object = new GrantState(state, env)
  const call = (method: string, key = GRANT, value?: string, rotation?: { from?: string; to: string }) => object.fetch(new Request('https://grant-state/storage', {
    method: 'POST', body: JSON.stringify({ method, key, value, rotation }),
  }))
  const rotate = (from: string, to: string) => call('put', GRANT,
    JSON.stringify({ previousRefreshTokenId: from, refreshTokenId: to }), { from, to })
  env.GRANT_STATE = {
    idFromName: (name: string) => name,
    get: () => ({ fetch: (input: string, init?: RequestInit) => object.fetch(new Request(input, init)) }),
  } as unknown as DurableObjectNamespace
  return { records, kv, state, call, rotate, storage: () => grantStorage(env), restart: () => { object = new GrantState(state, env) } }
}

describe('atomic refresh rotation', () => {
  async function pendingRefresh(stale = false) {
    const context = setup()
    const expiresAt = Math.floor(Date.now() / 1000) + 3600
    const prior = JSON.stringify({
      refreshTokenId: stale ? 'stale-successor' : 'initial',
      previousRefreshTokenId: stale ? 'initial' : undefined,
      encryptedProps: 'original', expiresAt,
    })
    // After a rollback, KV can still return the discarded successor. The
    // provider accepts its previous token; the durable head remains authoritative.
    if (stale) await context.state.storage.put('refreshTokenId', 'initial')
    context.records.set(GRANT, prior)
    const storage = context.storage()
    await storage.get(GRANT, 'json')
    await storage.put(GRANT, JSON.stringify({
      refreshTokenId: 'successor', previousRefreshTokenId: 'initial', encryptedProps: 'replacement', expiresAt,
    }), { expiration: expiresAt })
    return { ...context, storage, prior, expiresAt }
  }

  it.each([false, true])('restores the usable grant and expiration across object restarts (stale read: %s)', async (stale) => {
    const { storage, kv, records, restart, rotate, prior, expiresAt } = await pendingRefresh(stale)
    restart()
    kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    await expect(storage.put(TOKEN, 'rejected')).rejects.toThrow('429 Too Many Requests')
    restart()
    // Reads must ignore the discarded KV successor, without another KV write.
    expect(records.get(GRANT)).not.toBe(prior)
    expect(kv.put).toHaveBeenCalledTimes(2)
    expect(await storage.get(GRANT)).toBe(prior)
    expect(await storage.get(GRANT, 'json')).toMatchObject({ expiresAt })
    expect((await rotate('initial', 'retry')).status).toBe(204)
    expect(await storage.get(GRANT)).toBe(records.get(GRANT))
  })

  it('excludes competing refreshes until the rejected token write has been recovered', async () => {
    const { storage, kv, rotate, state } = await pendingRefresh()
    expect((await rotate('initial', 'competitor')).status).toBe(409)
    let entered!: () => void
    const restoring = new Promise<void>((resolve) => { entered = resolve })
    let resume!: () => void
    const paused = new Promise<void>((resolve) => { resume = resolve })
    kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    const put = state.storage.put.bind(state.storage)
    vi.spyOn(state.storage, 'put').mockImplementationOnce(async (...args: Parameters<typeof put>) => {
      entered()
      await paused
      return put(...args)
    })
    const rejected = expect(storage.put(TOKEN, 'rejected')).rejects.toThrow('429 Too Many Requests')
    await restoring
    const retry = rotate('initial', 'retry')
    try {
      await new Promise<void>((resolve) => setImmediate(resolve))
      expect(kv.put).toHaveBeenCalledTimes(2)
    } finally {
      resume()
    }
    await rejected
    expect((await retry).status).toBe(204)
    expect((await rotate('initial', 'competitor')).status).toBe(409)
  })

  it.each(['uncertain token', 'failed restore'])('keeps the successor reserved after %s storage failure', async (failure) => {
    const { storage, kv, records, rotate, restart, state } = await pendingRefresh()
    if (failure === 'uncertain token') {
      kv.put.mockImplementationOnce(async (key, value) => {
        records.set(key, value)
        throw new Error('Connection lost')
      })
    } else {
      kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
      vi.spyOn(state.storage, 'put').mockRejectedValueOnce(new Error('Connection lost'))
    }
    await expect(storage.put(TOKEN, 'possibly persisted')).rejects.toThrow('Connection lost')
    restart()
    expect((await rotate('initial', 'retry')).status).toBe(409)
  })

  it('does not roll back a later rotation on a delayed token rejection', async () => {
    const { storage, kv, records, rotate } = await pendingRefresh()
    expect((await rotate('successor', 'later')).status).toBe(204)
    const later = records.get(GRANT)
    kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    await expect(storage.put(TOKEN, 'delayed')).rejects.toThrow('429 Too Many Requests')
    expect(records.get(GRANT)).toBe(later)
    expect((await rotate('initial', 'retry')).status).toBe(409)
    expect((await rotate('later', 'next')).status).toBe(204)
  })

  it.each([false, true])('does not restore a revoked grant (previous recovery: %s)', async (recovered) => {
    const { storage, kv, records, call, restart, state } = await pendingRefresh()
    if (recovered) {
      kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
      await expect(storage.put(TOKEN, 'rejected')).rejects.toThrow('429 Too Many Requests')
    }
    expect((await call('delete')).status).toBe(204)
    restart()
    await expect(storage.put(TOKEN, 'late')).rejects.toThrow('Grant revoked')
    expect(await storage.get(GRANT)).toBeNull()
    expect(records.has(GRANT)).toBe(false)
    expect(await state.storage.get('recoveredGrant')).toBeUndefined()
    expect(kv.put).toHaveBeenCalledTimes(recovered ? 2 : 1)
  })

  it('rejects a reused predecessor after restart even when KV returns stale data', async () => {
    const { records, rotate, restart, kv } = setup()
    const initial = JSON.stringify({ refreshTokenId: 'initial' })
    records.set(GRANT, initial)
    expect((await rotate('initial', 'winner')).status).toBe(204)
    restart()
    records.set(GRANT, initial)
    expect((await rotate('initial', 'loser')).status).toBe(409)
    expect(kv.put).toHaveBeenCalledTimes(1)
    expect((await rotate('winner', 'next')).status).toBe(204)
  })

  it('allows retry after KV explicitly rejects the rotation write', async () => {
    const { records, rotate, restart, kv } = setup()
    records.set(GRANT, JSON.stringify({ refreshTokenId: 'initial' }))
    kv.put.mockRejectedValueOnce(new Error('KV PUT failed: 429 Too Many Requests'))
    await expect(rotate('initial', 'rejected')).rejects.toThrow('429 Too Many Requests')
    restart()
    expect((await rotate('initial', 'retry')).status).toBe(204)
  })

  it('retains the reservation when a write may have committed', async () => {
    const { records, rotate, restart, kv } = setup()
    records.set(GRANT, JSON.stringify({ refreshTokenId: 'initial' }))
    kv.put.mockImplementationOnce(async (key, value) => {
      records.set(key, value)
      throw new Error('Connection lost')
    })
    await expect(rotate('initial', 'uncertain')).rejects.toThrow('Connection lost')
    restart()
    expect((await rotate('initial', 'retry')).status).toBe(409)
    expect(kv.put).toHaveBeenCalledTimes(1)
  })

  it('does not write KV if the durable reservation fails', async () => {
    const { records, rotate, kv, state } = setup()
    records.set(GRANT, JSON.stringify({ refreshTokenId: 'initial' }))
    vi.spyOn(state.storage, 'put').mockRejectedValueOnce(new Error('Storage unavailable'))
    await expect(rotate('initial', 'rejected')).rejects.toThrow('Storage unavailable')
    expect(kv.put).not.toHaveBeenCalled()
    expect((await rotate('initial', 'retry')).status).toBe(204)
  })
})

describe('authoritative grant revocation', () => {
  it('persists individual token revocation across restarts without revoking its grant or sibling tokens', async () => {
    const { call, restart, records, kv } = setup()
    expect((await call('delete', TOKEN)).status).toBe(204)
    restart()
    records.set(TOKEN, 'stale KV token')
    expect(await (await call('get', TOKEN)).json()).toBeNull()
    expect((await call('put', TOKEN, 'late write')).status).toBe(409)
    expect(kv.get).not.toHaveBeenCalled()
    expect(kv.put).not.toHaveBeenCalled()

    expect(await (await call('get', GRANT)).json()).toBe('grant data')
    expect((await call('put', GRANT, 'refreshed grant')).status).toBe(204)
    const sibling = 'token:user:grant:sibling'
    expect((await call('put', sibling, 'sibling token')).status).toBe(204)
    expect(await (await call('get', sibling)).json()).toBe('sibling token')
  })

  it('persists revocation across object restarts and rejects stale grant and token writes', async () => {
    const { call, restart, records, kv } = setup()
    expect((await call('delete')).status).toBe(204)
    restart()
    records.set(GRANT, 'stale KV grant')
    for (const key of [GRANT, TOKEN]) {
      expect(await (await call('get', key)).json()).toBeNull()
      expect((await call('put', key, 'late write')).status).toBe(409)
    }
    expect(kv.put).not.toHaveBeenCalled()
    expect(kv.get).not.toHaveBeenCalled()
  })

  it.each([GRANT, TOKEN])('serializes revocation behind an in-progress KV write for %s', async (key) => {
    const { call, kv, records } = setup()
    let entered!: () => void
    const writing = new Promise<void>((resolve) => { entered = resolve })
    let resume!: () => void
    const paused = new Promise<void>((resolve) => { resume = resolve })
    kv.put.mockImplementationOnce(async (key, value) => {
      entered()
      await paused
      records.set(key, value)
    })
    const write = call('put', key, 'refreshed data')
    await writing
    const revoke = call('delete', key)
    try {
      await new Promise<void>((resolve) => setImmediate(resolve))
      expect(kv.delete).not.toHaveBeenCalled()
    } finally {
      resume()
    }
    expect((await write).status).toBe(204)
    expect((await revoke).status).toBe(204)
    expect(records.has(key)).toBe(false)
    expect((await call('put', TOKEN, 'late access token')).status).toBe(409)
  })

  it.each([GRANT, TOKEN])('retains revocation of %s even if physical KV deletion fails', async (key) => {
    const { call, restart, kv } = setup()
    kv.delete.mockRejectedValueOnce(new Error('KV unavailable'))
    await expect(call('delete', key)).rejects.toThrow('KV unavailable')
    restart()
    expect(await (await call('get', TOKEN)).json()).toBeNull()
    expect((await call('put', key, 'late write')).status).toBe(409)
    expect((await call('delete', key)).status).toBe(204)
  })

  it.each([GRANT, TOKEN])('does not acknowledge revocation of %s when its durable marker cannot be persisted', async (key) => {
    const { call, state, kv } = setup()
    vi.spyOn(state.storage, 'put').mockRejectedValueOnce(new Error('Storage unavailable'))
    await expect(call('delete', key)).rejects.toThrow('Storage unavailable')
    expect(kv.delete).not.toHaveBeenCalled()
    expect((await call('delete', key)).status).toBe(204)
  })

  it('propagates authoritative-state read failures instead of falling back to KV', async () => {
    const { call, state, kv } = setup()
    vi.spyOn(state.storage, 'get').mockRejectedValue(new Error('Storage unavailable'))
    await expect(call('get', TOKEN)).rejects.toThrow('Storage unavailable')
    await expect(call('put', GRANT, 'refresh')).rejects.toThrow('Storage unavailable')
    expect(kv.get).not.toHaveBeenCalled()
    expect(kv.put).not.toHaveBeenCalled()
  })
})
