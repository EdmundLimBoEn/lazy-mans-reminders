import type { AuthRequest, OAuthHelpers } from '@cloudflare/workers-oauth-provider'
import { createClient } from '@supabase/supabase-js'
import { MCP_RESOURCE, PENDING_AUTH_TTL_SECONDS, TOOLS } from './constants'
import { resolveSession } from './auth'
import type { BoundProps } from './session'

const PENDING_PREFIX = 'pending-auth:'
const STATE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function json(data: unknown, status = 200, extra?: HeadersInit): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
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
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

async function bindAuthorization(request: Request, env: Env): Promise<Response> {
  const cors = corsHeaders(request, env)

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ') || !env.SUPABASE_ANON_KEY) {
    return json({ error: 'unauthorized' }, 401, cors)
  }

  const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await supabase.auth.getUser(authorization.slice('Bearer '.length).trim())
  if (error || !data.user) return json({ error: 'unauthorized' }, 401, cors)

  const oauth = oauthHelpers(env)
  if (!oauth) return json({ error: 'server_misconfigured' }, 500, cors)

  let body: { state?: unknown }
  try {
    body = await request.json() as { state?: unknown }
  } catch {
    return json({ error: 'invalid_body' }, 400, cors)
  }

  const state = typeof body.state === 'string' ? body.state : ''
  if (!STATE.test(state)) return json({ error: 'invalid_state' }, 400, cors)

  const stored = await env.OAUTH_KV.get(`${PENDING_PREFIX}${state}`, 'json')
  if (!stored) return json({ error: 'expired_state' }, 400, cors)
  const oauthRequest = stored as AuthRequest

  const client = await oauth.lookupClient(oauthRequest.clientId)
  const agentName = client?.clientName?.trim() || 'Agent'
  const metadata = data.user.user_metadata as Record<string, unknown> | undefined
  const fullName = typeof metadata?.full_name === 'string' ? metadata.full_name : ''

  const granted = oauthRequest.scope.filter((scope) => scope === 'board')
  if (granted.length === 0) granted.push('board')

  const { redirectTo } = await oauth.completeAuthorization({
    request: oauthRequest,
    userId: data.user.id,
    metadata: { email: data.user.email ?? null, clientId: oauthRequest.clientId },
    scope: granted,
    props: {
      userId: data.user.id,
      tokenId: 'oauth',
      agentName,
      userEmail: data.user.email ?? '',
      userName: fullName,
    } satisfies BoundProps & { userEmail: string; userName: string },
  })

  await env.OAUTH_KV.delete(`${PENDING_PREFIX}${state}`)
  return json({ redirectTo }, 200, cors)
}

export async function handlePublicRequest(request: Request, env: Env): Promise<Response> {
  if (request.method === 'OPTIONS') {
    const cors = corsHeaders(request, env)
    return new Response(null, { status: 204, headers: cors })
  }

  const path = new URL(request.url).pathname
  if (request.method === 'GET' && (path === '/' || path === '/.well-known/mcp/server-card.json')) {
    return json(serverCard())
  }
  if (request.method === 'GET' && path === '/authorize') {
    return startAuthorize(request, env)
  }
  if (request.method === 'POST' && path === '/bind') {
    return bindAuthorization(request, env)
  }
  return json({ error: 'not_found' }, 404)
}
