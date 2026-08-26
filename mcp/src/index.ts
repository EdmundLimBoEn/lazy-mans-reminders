import { createMcpHandler } from 'agents/mcp/server'
import { resolveSession } from './auth'
import { createServer } from './server'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, DELETE',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept, MCP-Protocol-Version',
}

const TOOLS = [
  'list_reminders',
  'add_reminder',
  'complete_reminder',
  'reopen_reminder',
  'whoami',
] as const

const MCP_HOST = 'mcp.lmr.edmundlim.systems'

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
      'WWW-Authenticate': 'Bearer',
    },
  })
}

function serverCard() {
  return {
    name: "Lazy Man's Reminders",
    version: '1.0.0',
    url: '/mcp',
    auth: { type: 'bearer' },
    tools: TOOLS,
  }
}

async function fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS })
  }

  const path = new URL(request.url).pathname
  if (request.method === 'GET' && (path === '/' || path === '/.well-known/mcp/server-card.json')) {
    return json(serverCard())
  }

  if (path !== '/mcp') {
    return json({ error: 'not_found' }, 404)
  }

  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: 'server_misconfigured' }, 500)
  }

  const session = await resolveSession(env, request.headers.get('Authorization'), (promise) => {
    ctx.waitUntil(promise)
  })
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

export default { fetch } satisfies ExportedHandler<Env>
