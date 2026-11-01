import { describe, expect, it, vi } from 'vitest'
import { memoryState } from '../test/memoryObjects'
import { GrantState } from './grantState'

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
  const call = (method: string, key = GRANT, value?: string) => object.fetch(new Request('https://grant-state/storage', {
    method: 'POST', body: JSON.stringify({ method, key, value }),
  }))
  return { records, kv, state, call, restart: () => { object = new GrantState(state, env) } }
}

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
