import type { AuthRequest, ClientInfo } from '@cloudflare/workers-oauth-provider'
import { redirectOrigin, redirectUriRegistered } from './redirects'

export const BOARD_SCOPE = 'board'

/** What the `board` scope lets an agent do. Order is the order shown to the user. */
export const BOARD_PERMISSIONS = ['read', 'add', 'complete', 'reopen'] as const
export type BoardPermission = (typeof BOARD_PERMISSIONS)[number]

const MAX_CLIENT_NAME = 80

export type ConsentSummary = {
  client: {
    id: string
    /** Self-declared by the client at registration. Display as text; never treat as verified branding. */
    name: string | null
    uri: string | null
  }
  redirectOrigin: string
  scopes: string[]
  permissions: readonly BoardPermission[]
}

/** Collapse whitespace, drop control characters, and cap the length of a client-declared name. */
export function displayName(raw: string | undefined | null): string | null {
  if (typeof raw !== 'string') return null
  let out = ''
  for (const char of raw) {
    const code = char.codePointAt(0) ?? 0
    const control = code < 0x20 || (code >= 0x7f && code <= 0x9f) || code === 0x200b || code === 0x2028 || code === 0x2029
    out += control ? ' ' : char
  }
  out = out.replace(/\s+/g, ' ').trim()
  if (!out) return null
  return out.length > MAX_CLIENT_NAME ? `${out.slice(0, MAX_CLIENT_NAME - 1)}…` : out
}

function httpsOnly(value: string | undefined): string | null {
  if (!value) return null
  try {
    const url = new URL(value)
    return url.protocol === 'https:' ? url.toString() : null
  } catch {
    return null
  }
}

export function requestedBoardScope(scope: readonly string[] | undefined): boolean {
  return Array.isArray(scope) && scope.includes(BOARD_SCOPE)
}

export function consentCanApprove(summary: ConsentSummary | null): boolean {
  return summary !== null && summary.permissions.length === BOARD_PERMISSIONS.length
}

/**
 * Summary shown before Allow. Null when the pending request no longer matches a
 * registered client and an allowed redirect, so the UI cannot enable Allow.
 * Board permissions are included only when the client actually requested them.
 */
export function consentSummary(request: AuthRequest, client: ClientInfo | null): ConsentSummary | null {
  if (!client || client.clientId !== request.clientId) return null
  if (!redirectUriRegistered(request.redirectUri, client.redirectUris ?? [])) return null
  const origin = redirectOrigin(request.redirectUri)
  if (!origin) return null
  const board = requestedBoardScope(request.scope)
  return {
    client: {
      id: client.clientId,
      name: displayName(client.clientName),
      uri: httpsOnly(client.clientUri),
    },
    redirectOrigin: origin,
    scopes: board ? [BOARD_SCOPE] : [],
    permissions: board ? BOARD_PERMISSIONS : [],
  }
}

/**
 * RFC 6749 error redirect for a user denial. Only built when the redirect is
 * still registered, otherwise null so the caller fails closed.
 */
export function denialRedirect(request: AuthRequest, client: ClientInfo | null): string | null {
  if (!consentSummary(request, client)) return null
  const url = new URL(request.redirectUri)
  url.searchParams.set('error', 'access_denied')
  url.searchParams.set('error_description', 'The user denied the request')
  if (request.state) url.searchParams.set('state', request.state)
  if (request.issuer) url.searchParams.set('iss', request.issuer)
  return url.toString()
}
