import type { GrantSummary, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { displayName } from './consent'
import { redirectOrigin } from './redirects'

const PAGE_SIZE = 100
/** Upper bound on KV list pages per pass so a corrupt cursor cannot loop forever. */
const MAX_PAGES = 100

export type GrantView = {
  id: string
  clientId: string
  clientName: string | null
  redirectOrigin: string | null
  createdAt: number
  expiresAt: number | null
}

export type CleanupReport = {
  revoked: number
  failed: number
  remaining: number
  complete: boolean
}

/** Walk every page of the provider's per-user grant index. */
export async function listAllUserGrants(oauth: OAuthHelpers, userId: string): Promise<GrantSummary[]> {
  const items: GrantSummary[] = []
  let cursor: string | undefined
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const result = await oauth.listUserGrants(userId, cursor ? { limit: PAGE_SIZE, cursor } : { limit: PAGE_SIZE })
    for (const grant of result.items) {
      if (grant.userId === userId) items.push(grant)
    }
    if (!result.cursor) return items
    cursor = result.cursor
  }
  throw new Error('Grant listing did not terminate')
}

export async function describeGrants(oauth: OAuthHelpers, grants: GrantSummary[]): Promise<GrantView[]> {
  const names = new Map<string, string | null>()
  for (const grant of grants) {
    if (names.has(grant.clientId)) continue
    try {
      const client = await oauth.lookupClient(grant.clientId)
      names.set(grant.clientId, displayName(client?.clientName))
    } catch {
      names.set(grant.clientId, null)
    }
  }
  return grants
    .map((grant) => ({
      id: grant.id,
      clientId: grant.clientId,
      clientName: names.get(grant.clientId) ?? null,
      redirectOrigin: redirectOrigin(grant.redirectUri),
      createdAt: grant.createdAt,
      expiresAt: grant.expiresAt ?? null,
    }))
    .sort((a, b) => b.createdAt - a.createdAt)
}

/**
 * Revoke one grant only after confirming it is in this user's index.
 * `revokeGrant` keys on `{userId}:{grantId}` so a foreign grant id cannot
 * touch another user's data, but a miss is still not_found.
 */
export async function revokeUserGrant(
  oauth: OAuthHelpers,
  userId: string,
  grantId: string,
): Promise<'revoked' | 'not_found'> {
  const owned = await listAllUserGrants(oauth, userId)
  if (!owned.some((grant) => grant.id === grantId)) return 'not_found'
  await oauth.revokeGrant(grantId, userId)
  return 'revoked'
}

/**
 * Revoke every grant the user holds. Each revocation is attempted even when a
 * sibling fails, then the index is re-read. `complete` is true only when
 * nothing failed and nothing remains.
 */
export async function cleanupUserGrants(oauth: OAuthHelpers, userId: string): Promise<CleanupReport> {
  const grants = await listAllUserGrants(oauth, userId)
  const outcomes = await Promise.allSettled(
    grants.map((grant) => oauth.revokeGrant(grant.id, userId)),
  )
  const failed = outcomes.filter((outcome) => outcome.status === 'rejected').length
  const revoked = outcomes.length - failed
  const remaining = (await listAllUserGrants(oauth, userId)).length
  return { revoked, failed, remaining, complete: failed === 0 && remaining === 0 }
}
