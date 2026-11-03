import { getOAuthApi, OAuthError, OAuthProvider, type OAuthProviderOptions } from '@cloudflare/workers-oauth-provider'
import { createMcpHandler } from 'agents/mcp/server'
import { checkAccount, decideTokenExchange } from './accountGate'
import { grantStorage, type CodeClaim } from './grantState'
import { readBodyBytes } from './jsonBody'
import { MCP_HOSTS, mcpResourceForRequest, MCP_WWW_AUTHENTICATE } from './constants'
import { corsHeaders, handlePublicRequest, resolveExternalPat } from './oauth'
import { prepareOauthRequest, rewriteOauthPath } from './oauthCompat'
import { registrationRedirectError } from './redirects'
import { enforceRateLimit } from './rateLimit'
import { createServer } from './server'
import { sessionFromProps } from './session'
import { defaultIdentityDeps, type IdentityDeps } from './supabaseUser'

export { AuthorizationState } from './authorizationState'
export { GrantState } from './grantState'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, DELETE',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept, MCP-Protocol-Version',
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  })
}

function unauthorized(): Response {
  return new Response(JSON.stringify({ error: 'unauthorized' }), {
    status: 401,
    headers: {
      ...CORS,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'WWW-Authenticate': MCP_WWW_AUTHENTICATE,
    },
  })
}

async function handleMcp(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  deps: IdentityDeps,
): Promise<Response> {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: 'server_misconfigured' }, 500)
  }

  const session = sessionFromProps((ctx as ExecutionContext & { props?: unknown }).props)
  if (!session) return unauthorized()

  const account = await checkAccount(env, deps.accountExists, session.userId)
  if (account === 'unavailable') return json({ error: 'account_lookup_unavailable' }, 503)
  if (account === 'deleted') return unauthorized()

  if (request.method === 'POST') {
    // Bound streamed bytes before the SDK buffers and parses the body.
    const bytes = await readBodyBytes(request, 1024 * 1024)
    if (bytes instanceof Response) return bytes
    request = new Request(request, { body: bytes })
  }

  const handler = createMcpHandler(() => createServer(session, env), {
    route: '/mcp',
    allowedHostnames: [...MCP_HOSTS],
    allowedOriginHostnames: '*',
    corsOptions: { origin: '*' },
  })

  return handler.fetch(request, {
    authInfo: {
      token: session.tokenId,
      clientId: session.tokenId,
      scopes: ['board'],
      extra: { userId: session.userId, agentName: session.agentName },
    },
  })
}

function providerOptions(env: Env, deps: IdentityDeps, resource: string, ctx: ExecutionContext, claim: CodeClaim = {}): OAuthProviderOptions<Env> {
  const options: OAuthProviderOptions<Env> = {
    apiRoute: '/mcp',
    apiHandler: { fetch: (request, nextEnv, ctx) => handleMcp(request, nextEnv, ctx, deps) },
    defaultHandler: {
      fetch: (request, nextEnv) => handlePublicRequest(request, nextEnv, deps,
        (pendingResource) => getOAuthApi(providerOptions(nextEnv, deps, pendingResource, ctx), nextEnv)),
    },
    authorizeEndpoint: '/authorize',
    tokenEndpoint: '/token',
    clientRegistrationEndpoint: '/register',
    scopesSupported: ['board'],
    clientIdMetadataDocumentEnabled: true,
    clientRegistrationCallback(registration) {
      return registrationRedirectError(registration.clientMetadata)
    },
    async tokenExchangeCallback(exchange) {
      const decision = await decideTokenExchange(env, deps.accountExists, exchange, (grantId, userId) => {
        return getOAuthApi(options, env).revokeGrant(grantId, userId)
      })
      if (decision.kind === 'invalid_scope') {
        throw new OAuthError('invalid_scope', { description: 'The board scope is required' })
      }
      if (decision.kind === 'unavailable') {
        throw new OAuthError('temporarily_unavailable', {
          description: 'Account lookup is unavailable',
          statusCode: 503,
        })
      }
      if (decision.kind === 'deleted') {
        throw new OAuthError('invalid_grant', { description: 'Account no longer exists' })
      }
      if (exchange.grantType === 'authorization_code') {
        // The provider has validated the client, code and PKCE before this
        // callback. It creates one code per grant, but consumes it in KV later.
        let consumed: boolean
        try {
          const id = env.AUTHORIZATION_STATE.idFromName(`code:${exchange.userId}:${exchange.grantId}`)
          const attempt = crypto.randomUUID()
          const response = await env.AUTHORIZATION_STATE.get(id).fetch('https://authorization-state/redeem', {
            method: 'POST', body: JSON.stringify({ attempt }),
          })
          if (!response.ok) throw new Error()
          consumed = (await response.json<{ consumed: boolean }>()).consumed === true
          if (consumed) {
            claim.key = `grant:${exchange.userId}:${exchange.grantId}`
            claim.attempt = attempt
          }
        } catch {
          throw new OAuthError('temporarily_unavailable', {
            description: 'Token issuance is temporarily unavailable; retry shortly',
            statusCode: 503,
          })
        }
        if (!consumed) {
          throw new OAuthError('invalid_grant', { description: 'Authorization code already used' })
        }
      }
      return { newProps: decision.newProps }
    },
    resourceMetadata: {
      resource,
      authorization_servers: MCP_HOSTS.map((host) => `https://${host}`),
      scopes_supported: ['board'],
      resource_name: "Lazy Man's Reminders",
    },
    async resolveExternalToken(input) {
      return resolveExternalPat(input, (promise) => ctx.waitUntil(promise))
    },
  }
  return options
}

async function checkCodeRedirect(request: Request, env: Env): Promise<Response | null> {
  if (request.method !== 'POST' || new URL(request.url).pathname !== '/token' ||
      request.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase() !== 'application/x-www-form-urlencoded') return null

  let form: FormData
  try {
    form = await request.clone().formData()
  } catch {
    return null // Let the provider report malformed requests.
  }
  // Match the provider's duplicate-parameter rejection before inspecting values.
  for (const key of form.keys()) {
    if (key !== 'resource' && form.getAll(key).length > 1) return null
  }
  if (form.get('grant_type') !== 'authorization_code') return null
  const code = form.get('code')
  if (typeof code !== 'string' || code.split(':').length !== 3) return null
  const [userId, grantId] = code.split(':')
  // Provider 0.10.3 stores the issuing redirectUri on the grant, but only checks
  // client registration at redemption. Reuse its record and existing code format.
  let grant: { redirectUri?: string } | null
  try {
    grant = await env.OAUTH_KV.get<{ redirectUri?: string }>(`grant:${userId}:${grantId}`, 'json')
  } catch (error) {
    const rateLimited = (error instanceof OAuthError && error.statusCode === 429) ||
      (error instanceof Error && /429 Too Many Requests/i.test(error.message))
    const response = json({
      error: 'temporarily_unavailable',
      error_description: 'Token issuance is temporarily unavailable; retry shortly',
    }, rateLimited ? 429 : 503)
    response.headers.set('Retry-After', '30')
    response.headers.set('Access-Control-Expose-Headers', 'Retry-After')
    return response
  }
  if (!grant?.redirectUri || form.get('redirect_uri') !== grant.redirectUri) {
    return json({ error: 'invalid_grant', error_description: 'Redirect URI does not match the authorization request' }, 400)
  }
  return null
}

export async function handleWorkerFetch(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  deps: IdentityDeps = defaultIdentityDeps,
): Promise<Response> {
  const path = rewriteOauthPath(new URL(request.url).pathname)
  // Match the provider's public routes; consent and account routes keep their allowlist.
  const publicCors = path.startsWith('/mcp') || path === '/token' || path === '/register'
  const origin = request.headers.get('Origin')
  const limitCors = publicCors ? (origin ? {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': '*',
    'Access-Control-Allow-Headers': 'Authorization, *',
    'Access-Control-Expose-Headers': 'WWW-Authenticate, Retry-After',
  } : {}) : corsHeaders(request, env)
  const limited = await enforceRateLimit(request, env, limitCors)
  if (limited) return limited
  const prepared = await prepareOauthRequest(request)
  if (prepared instanceof Response) return prepared
  const claim: CodeClaim = {}
  env = { ...env, OAUTH_KV: grantStorage(env, claim) }
  const redirectError = await checkCodeRedirect(prepared, env)
  if (redirectError) return redirectError
  return new OAuthProvider(providerOptions(env, deps, mcpResourceForRequest(prepared), ctx, claim)).fetch(prepared, env, ctx)
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return handleWorkerFetch(request, env, ctx)
  },
}
