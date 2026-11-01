import type { GrantSummary, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it } from 'vitest'
import { cleanupUserGrants, describeGrants, listAllUserGrants, revokeUserGrant } from './grants'

function grant(partial: Partial<GrantSummary> & Pick<GrantSummary, 'id' | 'userId'>): GrantSummary {
  return {
    clientId: 'client-a',
    scope: ['board'],
    metadata: { email: 'hidden@example.com' },
    createdAt: 1,
    ...partial,
  }
}

function oauthFor(grants: GrantSummary[], options?: { fail?: string; pages?: GrantSummary[][] }): OAuthHelpers & { revoked: string[] } {
  const revoked: string[] = []
  let page = 0
  const helpers = {
    async listUserGrants(userId: string, list?: { cursor?: string }) {
      if (options?.pages) {
        const items = options.pages[page] ?? []
        page += 1
        const more = page < options.pages.length
        return { items: items.filter((item) => item.userId === userId), cursor: more ? `page-${page}` : undefined }
      }
      if (list?.cursor === 'stuck') return { items: [], cursor: 'stuck' }
      return { items: grants.filter((item) => item.userId === userId) }
    },
    async revokeGrant(grantId: string, userId: string) {
      if (options?.fail === grantId) throw new Error('kv down')
      const index = grants.findIndex((item) => item.id === grantId && item.userId === userId)
      if (index < 0) throw new Error('missing grant')
      grants.splice(index, 1)
      revoked.push(`${userId}:${grantId}`)
    },
    revoked,
  }
  return helpers as unknown as OAuthHelpers & { revoked: string[] }
}

describe('grant ownership', () => {
  it.each([false, true])('bounds cleanup concurrency and verifies all results (failure: %s)', async (fail) => {
    const grants = Array.from({ length: 13 }, (_, i) => grant({ id: `grant-${i}`, userId: 'user-a' }))
    const attempted: string[] = []
    let active = 0
    let peak = 0
    let listings = 0
    const oauth = {
      async listUserGrants(userId: string) {
        expect(userId).toBe('user-a')
        expect(active).toBe(0)
        if (listings++ > 0) expect(attempted).toHaveLength(13)
        return { items: [...grants] }
      },
      async revokeGrant(id: string, userId: string) {
        expect(userId).toBe('user-a')
        attempted.push(id)
        active += 1
        peak = Math.max(peak, active)
        await new Promise((resolve) => setTimeout(resolve, 0))
        active -= 1
        if (fail && id === 'grant-0') throw new Error('kv down')
        // A successful call can still leave an indexed grant behind.
        if (fail && id === 'grant-12') return
        grants.splice(grants.findIndex((item) => item.id === id), 1)
      },
    } as unknown as OAuthHelpers

    expect(await cleanupUserGrants(oauth, 'user-a')).toEqual({
      revoked: fail ? 12 : 13,
      failed: fail ? 1 : 0,
      remaining: fail ? 2 : 0,
      complete: !fail,
    })
    expect(peak).toBe(4)
    expect(new Set(attempted).size).toBe(13)
    expect(listings).toBe(2)
  })

  it('revokes client A without touching client B, and a second user cannot revoke A', async () => {
    const grants = [
      grant({ id: 'grant-a-aaaaaaaa', userId: 'user-a', clientId: 'client-a' }),
      grant({ id: 'grant-b-bbbbbbbb', userId: 'user-a', clientId: 'client-b' }),
    ]
    const oauth = oauthFor(grants)
    expect(await revokeUserGrant(oauth, 'user-b', 'grant-a-aaaaaaaa')).toBe('not_found')
    expect(oauth.revoked).toEqual([])
    expect(await revokeUserGrant(oauth, 'user-a', 'grant-a-aaaaaaaa')).toBe('revoked')
    expect(grants.map((item) => item.id)).toEqual(['grant-b-bbbbbbbb'])
  })

  it('reports cleanup incomplete when a revoke fails and does not claim the rest are gone', async () => {
    const grants = [
      grant({ id: 'grant-ok-aaaaaaa', userId: 'user-a' }),
      grant({ id: 'grant-bad-bbbbbb', userId: 'user-a' }),
    ]
    const report = await cleanupUserGrants(oauthFor(grants, { fail: 'grant-bad-bbbbbb' }), 'user-a')
    expect(report.complete).toBe(false)
    expect(report.failed).toBe(1)
    expect(report.remaining).toBe(1)
  })

  it('stops walking a cursor that never ends', async () => {
    const oauth = {
      async listUserGrants() {
        return { items: [], cursor: 'stuck' }
      },
    } as unknown as OAuthHelpers
    await expect(listAllUserGrants(oauth, 'user-a')).rejects.toThrow(/did not terminate/)
  })
})

describe('grant descriptions', () => {
  it('resolves distinct clients concurrently within a fixed bound and preserves descriptions', async () => {
    const grants = Array.from({ length: 26 }, (_, i) => grant({
      id: `grant-${i}`,
      userId: 'user-a',
      clientId: `client-${i % 13}`,
      createdAt: i,
      redirectUri: 'https://example.com/callback',
      ...(i === 25 ? { expiresAt: 100 } : {}),
    }))
    const attempted: string[] = []
    let active = 0
    let peak = 0
    const oauth = {
      async lookupClient(id: string) {
        attempted.push(id)
        active += 1
        peak = Math.max(peak, active)
        // Finish out of order, including a failed lookup in the first batch.
        await new Promise((resolve) => setTimeout(resolve, id === 'client-0' ? 10 : 0))
        active -= 1
        if (id === 'client-1') throw new Error('kv down')
        if (id === 'client-2') return undefined
        return { clientName: `Name ${id}` }
      },
    } as unknown as OAuthHelpers

    const descriptions = await describeGrants(oauth, grants)
    expect(peak).toBe(4)
    expect(active).toBe(0)
    expect(attempted).toHaveLength(13)
    expect(new Set(attempted).size).toBe(13)
    expect(descriptions).toEqual([...grants].reverse().map((item) => ({
      id: item.id,
      clientId: item.clientId,
      clientName: ['client-1', 'client-2'].includes(item.clientId) ? null : `Name ${item.clientId}`,
      redirectOrigin: 'https://example.com',
      createdAt: item.createdAt,
      expiresAt: item.expiresAt ?? null,
    })))
  })

  it('does not look up clients for an empty listing', async () => {
    let calls = 0
    const oauth = {
      async lookupClient() { calls += 1 },
    } as unknown as OAuthHelpers
    expect(await describeGrants(oauth, [])).toEqual([])
    expect(calls).toBe(0)
  })
})
