import type { AuthRequest, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { MCP_RESOURCE, PENDING_AUTH_TTL_SECONDS, TOOLS } from './constants'
import { resolveSession } from './auth'
import {
  consentCanApprove,
  consentSummary,
  denialRedirect,
  type ConsentSummary,
} from './consent'
import { cleanupUserGrants, describeGrants, listAllUserGrants, revokeUserGrant } from './grants'
import type { BoundProps } from './session'
import { bearerToken, defaultIdentityDeps, type IdentityDeps } from './supabaseUser'

const PENDING_PREFIX = 'pending-auth:'
const STATE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const GRANT_ID = /^[A-Za-z0-9_-]{8,128}$/

function json(data: unknown, status = 200, extra?: HeadersInit): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...extra,
    },
  })
}

export function allowedWebOrigins(env: Env): string[] {
  return env.WEB_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
}

export function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin')
  if (!origin || !allowedWebOrigins(env).includes(origin)) return {}
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    Vary: 'Origin',
  }
}

export function serverCard() {
  // This card's `auth.type` is a single string. Cloudflare workers-oauth-provider
  // has no dual-auth discovery field: RFC 9728 resource metadata is OAuth-only,
  // while `resolveExternalToken` still accepts bearer agent keys at request time.
  // SEP-1649 `authentication.schemes` is a different document shape than this
  // card (`name` / `url` / `auth` / `tools`). Do not invent `auth.types` or similar.
  // Grok Bot and other static-header hosts should use board copy plus plugin
  // variable LMR_AGENT_TOKEN rather than this card.
  return {
    name: "Lazy Man's Reminders",
    version: '1.0.0',
    url: '/mcp',
    auth: { type: 'oauth' },
    tools: TOOLS,
  }
}

export async function resolveExternalPat(input: {
  token: string
  request: Request
  env: Env
}): Promise<{ props: BoundProps; audience: string } | null> {
  const session = await resolveSession(input.env, `Bearer ${input.token}`)
  if (!session) return null
  return {
    props: {
      userId: session.userId,
      tokenId: session.tokenId,
      agentName: session.agentName,
    },
    audience: MCP_RESOURCE,
  }
}

function oauthHelpers(env: Env): OAuthHelpers | null {
  const helpers = (env as Env & { OAUTH_PROVIDER?: OAuthHelpers }).OAUTH_PROVIDER
  return helpers ?? null
}

type AuthorizeFailure = {
  code: string
  description: string
  redirectUri?: string
  state?: string
  issuer?: string
}

function asAuthorizeFailure(error: unknown): AuthorizeFailure | null {
  if (!error || typeof error !== 'object') return null
  const candidate = error as Partial<AuthorizeFailure>
  if (typeof candidate.code !== 'string' || typeof candidate.description !== 'string') return null
  return candidate as AuthorizeFailure
}

function asAuthRequest(value: unknown): AuthRequest | null {
  if (!value || typeof value !== 'object') return null
  const request = value as Partial<AuthRequest>
  if (typeof request.clientId !== 'string' || typeof request.redirectUri !== 'string') return null
  if (typeof request.responseType !== 'string') request.responseType = 'code'
  if (!Array.isArray(request.scope)) request.scope = []
  if (typeof request.state !== 'string') request.state = ''
  return request as AuthRequest
}

async function readJson(request: Request): Promise<Record<string, unknown> | Response> {
  try {
    const body = await request.json()
    if (!body || typeof body !== 'object' || Array.isArray(body)) return json({ error: 'invalid_body' }, 400)
    return body as Record<string, unknown>
  } catch {
    return json({ error: 'invalid_body' }, 400)
  }
}

async function requireUser(request: Request, env: Env, deps: IdentityDeps, cors: Record<string, string>) {
  const token = bearerToken(request)
  if (!token) return json({ error: 'unauthorized' }, 401, cors)
  const user = await deps.verifyUser(env, token)
  if (!user) return json({ error: 'unauthorized' }, 401, cors)
  return user
}

async function loadPending(env: Env, state: string): Promise<AuthRequest | null> {
  const stored = await env.OAUTH_KV.get(`${PENDING_PREFIX}${state}`, 'json')
  return asAuthRequest(stored)
}

async function startAuthorize(request: Request, env: Env): Promise<Response> {
  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500)

  let oauthRequest: AuthRequest
  try {
    oauthRequest = await oauth.parseAuthRequest(request)
  } catch (error) {
    const failed = asAuthorizeFailure(error)
    if (!failed) throw error
    if (!failed.redirectUri) {
      return json({ error: failed.code, error_description: failed.description }, 400)
    }
    const redirect = new URL(failed.redirectUri)
    redirect.searchParams.set('error', failed.code)
    redirect.searchParams.set('error_description', failed.description)
    if (failed.state) redirect.searchParams.set('state', failed.state)
    if (failed.issuer) redirect.searchParams.set('iss', failed.issuer)
    return Response.redirect(redirect.toString(), 302)
  }

  const state = crypto.randomUUID()
  await env.OAUTH_KV.put(
    `${PENDING_PREFIX}${state}`,
    JSON.stringify(oauthRequest),
    { expirationTtl: PENDING_AUTH_TTL_SECONDS },
  )

  const webOrigin = allowedWebOrigins(env)[0]
  if (!webOrigin) return json({ error: 'server_misconfigured' }, 500)
  const connect = new URL('/connect', webOrigin)
  connect.searchParams.set('state', state)
  return Response.redirect(connect.toString(), 302)
}

async function readConsent(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user
  const state = new URL(request.url).searchParams.get('state') ?? ''
  if (!STATE.test(state)) return json({ error: 'invalid_state' }, 400, cors)
  const pending = await summarizePending(env, state)
  if (pending instanceof Response) return json(await pending.json(), pending.status, cors)
  if (!consentCanApprove(pending)) return json({ error: 'board_not_requested', summary: pending }, 400, cors)
  return json({ summary: pending }, 200, cors)
}

async function summarizePending(env: Env, state: string): Promise<ConsentSummary | Response> {
  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500)
  const oauthRequest = await loadPending(env, state)
  if (!oauthRequest) return json({ error: 'expired_state' }, 400)
  const client = await oauth.lookupClient(oauthRequest.clientId)
  const summary = consentSummary(oauthRequest, client)
  if (!summary) return json({ error: 'untrusted_client' }, 400)
  return summary
}

async function denyConsent(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user
  const body = await readJson(request)
  if (body instanceof Response) return json(await body.json(), body.status, cors)
  const state = typeof body.state === 'string' ? body.state : ''
  if (!STATE.test(state)) return json({ error: 'invalid_state' }, 400, cors)

  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500, cors)
  const oauthRequest = await loadPending(env, state)
  await env.OAUTH_KV.delete(`${PENDING_PREFIX}${state}`)
  if (!oauthRequest) return json({ redirectTo: null }, 200, cors)
  const client = await oauth.lookupClient(oauthRequest.clientId)
  return json({ redirectTo: denialRedirect(oauthRequest, client) }, 200, cors)
}

async function bindAuthorization(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user

  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500, cors)

  const body = await readJson(request)
  if (body instanceof Response) return json(await body.json(), body.status, cors)
  const state = typeof body.state === 'string' ? body.state : ''
  if (!STATE.test(state)) return json({ error: 'invalid_state' }, 400, cors)

  const oauthRequest = await loadPending(env, state)
  if (!oauthRequest) return json({ error: 'expired_state' }, 400, cors)
  const client = await oauth.lookupClient(oauthRequest.clientId)
  const summary = consentSummary(oauthRequest, client)
  if (!consentCanApprove(summary)) {
    return json({ error: summary ? 'board_not_requested' : 'untrusted_client' }, 400, cors)
  }

  // Drop the pending record before creating the grant so a replayed Allow cannot
  // approve it again. KV is not transactional: two overlapping requests can both
  // still read it and create two grants for this same user.
  await env.OAUTH_KV.delete(`${PENDING_PREFIX}${state}`)

  try {
    const { redirectTo } = await oauth.completeAuthorization({
      request: oauthRequest,
      userId: user.id,
      metadata: {},
      scope: ['board'],
      props: {
        userId: user.id,
        tokenId: 'oauth',
        agentName: summary?.client.name || 'Agent',
      } satisfies BoundProps,
    })
    return json({ redirectTo }, 200, cors)
  } catch (error) {
    console.error('authorization completion failed', error instanceof Error ? error.name : 'error')
    return json({ error: 'authorization_failed' }, 400, cors)
  }
}

async function listGrants(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user
  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500, cors)
  try {
    const grants = await describeGrants(oauth, await listAllUserGrants(oauth, user.id))
    return json({ grants }, 200, cors)
  } catch (error) {
    console.error('grant list failed', error instanceof Error ? error.name : 'error')
    return json({ error: 'grant_list_failed' }, 503, cors)
  }
}

async function revokeGrant(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user
  const body = await readJson(request)
  if (body instanceof Response) return json(await body.json(), body.status, cors)
  const grantId = typeof body.grantId === 'string' ? body.grantId : ''
  if (!GRANT_ID.test(grantId)) return json({ error: 'invalid_grant' }, 400, cors)
  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500, cors)
  const outcome = await revokeUserGrant(oauth, user.id, grantId)
  if (outcome === 'not_found') return json({ error: 'not_found' }, 404, cors)
  return json({ revoked: true }, 200, cors)
}

async function cleanupGrants(request: Request, env: Env, deps: IdentityDeps): Promise<Response> {
  const cors = corsHeaders(request, env)
  const user = await requireUser(request, env, deps, cors)
  if (user instanceof Response) return user
  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured', complete: false }, 500, cors)
  try {
    const report = await cleanupUserGrants(oauth, user.id)
    return json(report, report.complete ? 200 : 503, cors)
  } catch (error) {
    console.error('grant cleanup failed', error instanceof Error ? error.name : 'error')
    return json({ revoked: 0, failed: 1, remaining: 1, complete: false }, 503, cors)
  }
}

export async function handlePublicRequest(
  request: Request,
  env: Env,
  deps: IdentityDeps = defaultIdentityDeps,
): Promise<Response> {
  if (request.method === 'OPTIONS') {
    const cors = corsHeaders(request, env)
    return new Response(null, { status: 204, headers: cors })
  }

  const path = new URL(request.url).pathname.replace(/\/+$/, '') || '/'
  if (request.method === 'GET' && (path === '/' || path === '/.well-known/mcp/server-card.json')) {
    return json(serverCard())
  }
  if ((request.method === 'GET' || request.method === 'POST') && path === '/authorize') {
    return startAuthorize(request, env)
  }
  if (request.method === 'GET' && path === '/consent') {
    return readConsent(request, env, deps)
  }
  if (request.method === 'POST' && path === '/consent/deny') {
    return denyConsent(request, env, deps)
  }
  if (request.method === 'POST' && path === '/bind') {
    return bindAuthorization(request, env, deps)
  }
  if (request.method === 'GET' && path === '/grants') {
    return listGrants(request, env, deps)
  }
  if (request.method === 'POST' && path === '/grants/revoke') {
    return revokeGrant(request, env, deps)
  }
  if (request.method === 'POST' && path === '/account/grants/cleanup') {
    return cleanupGrants(request, env, deps)
  }
  return json({ error: 'not_found' }, 404)
}
