import { OAuthProvider } from '@cloudflare/workers-oauth-provider'
import { createMcpHandler } from 'agents/mcp/server'
import { MCP_HOST, MCP_RESOURCE, MCP_WWW_AUTHENTICATE } from './constants'
import { handlePublicRequest, resolveExternalPat } from './oauth'
import { prepareOauthRequest } from './oauthCompat'
import { createServer } from './server'
import { sessionFromProps } from './session'

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
    },
  })
}

function unauthorized(): Response {
  return new Response(JSON.stringify({ error: 'unauthorized' }), {
    status: 401,
    headers: {
      ...CORS,
      'Content-Type': 'application/json',
      'WWW-Authenticate': MCP_WWW_AUTHENTICATE,
    },
  })
}

async function handleMcp(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: 'server_misconfigured' }, 500)
  }

  const session = sessionFromProps((ctx as ExecutionContext & { props?: unknown }).props)
  if (!session) return unauthorized()

  const hostname = new URL(request.url).hostname
  const allowedHostnames = [MCP_HOST]
  if (hostname.endsWith('.workers.dev') && !allowedHostnames.includes(hostname)) {
    allowedHostnames.push(hostname)
  }

  const handler = createMcpHandler(() => createServer(session, env), {
    route: '/mcp',
    allowedHostnames,
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

const provider = new OAuthProvider<Env>({
  apiRoute: '/mcp',
  apiHandler: { fetch: handleMcp },
  defaultHandler: { fetch: handlePublicRequest },
  authorizeEndpoint: '/authorize',
  tokenEndpoint: '/token',
  clientRegistrationEndpoint: '/register',
  scopesSupported: ['board'],
  clientIdMetadataDocumentEnabled: true,
  resourceMetadata: {
    resource: MCP_RESOURCE,
    authorization_servers: [`https://${MCP_HOST}`],
    scopes_supported: ['board'],
    resource_name: "Lazy Man's Reminders",
  },
  async resolveExternalToken(input) {
    return resolveExternalPat(input)
  },
})

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return provider.fetch(await prepareOauthRequest(request), env, ctx)
  },
}
