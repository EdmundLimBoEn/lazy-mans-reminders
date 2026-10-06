import type { GrantSummary, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it } from 'vitest'
import { cleanupUserGrants, listAllUserGrants, revokeUserGrant } from './grants'

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
