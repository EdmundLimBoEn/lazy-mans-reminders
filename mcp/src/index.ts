import { getOAuthApi, OAuthError, OAuthProvider, type OAuthProviderOptions } from '@cloudflare/workers-oauth-provider'
import { createMcpHandler } from 'agents/mcp/server'
import { checkAccount, decideTokenExchange } from './accountGate'
import { MCP_HOST, MCP_RESOURCE, MCP_WWW_AUTHENTICATE } from './constants'
import { corsHeaders, handlePublicRequest, resolveExternalPat } from './oauth'
import { prepareOauthRequest } from './oauthCompat'
import { registrationRedirectError } from './redirects'
import { enforceRateLimit } from './rateLimit'
import { createServer } from './server'
import { sessionFromProps } from './session'
import { defaultIdentityDeps, type IdentityDeps } from './supabaseUser'

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

  const handler = createMcpHandler(() => createServer(session, env), {
    route: '/mcp',
    allowedHostnames: [MCP_HOST],
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

function createProvider(env: Env, deps: IdentityDeps): OAuthProvider<Env> {
  const options = {
    apiRoute: '/mcp',
    apiHandler: { fetch: (request, nextEnv, ctx) => handleMcp(request, nextEnv, ctx, deps) },
    defaultHandler: { fetch: (request, nextEnv) => handlePublicRequest(request, nextEnv, deps) },
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
      if (decision.kind === 'unavailable') {
        throw new OAuthError('temporarily_unavailable', {
          description: 'Account lookup is unavailable',
          statusCode: 503,
        })
      }
      if (decision.kind === 'deleted') {
        throw new OAuthError('invalid_grant', { description: 'Account no longer exists' })
      }
      return { newProps: decision.newProps }
    },
    resourceMetadata: {
      resource: MCP_RESOURCE,
      authorization_servers: [`https://${MCP_HOST}`],
      scopes_supported: ['board'],
      resource_name: "Lazy Man's Reminders",
    },
    async resolveExternalToken(input) {
      return resolveExternalPat(input)
    },
  } satisfies OAuthProviderOptions<Env>
  return new OAuthProvider(options)
}

export async function handleWorkerFetch(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  deps: IdentityDeps = defaultIdentityDeps,
): Promise<Response> {
  const limited = await enforceRateLimit(request, env, corsHeaders(request, env))
  if (limited) return limited
  return createProvider(env, deps).fetch(await prepareOauthRequest(request), env, ctx)
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return handleWorkerFetch(request, env, ctx)
  },
}
