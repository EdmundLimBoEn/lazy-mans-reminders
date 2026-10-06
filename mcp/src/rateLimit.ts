const AUTH_PATHS = new Set([
  '/register',
  '/authorize',
  '/token',
  '/bind',
  '/consent',
  '/consent/deny',
  '/grants',
  '/grants/revoke',
  '/account/grants/cleanup',
])

export function rateLimitBucket(pathname: string): 'auth' | 'mcp' | null {
  const path = pathname.replace(/\/+$/, '') || '/'
  if (path === '/mcp') return 'mcp'
  if (AUTH_PATHS.has(path)) return 'auth'
  return null
}

function json(data: unknown, status: number, extra?: HeadersInit): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...extra,
    },
  })
}

/** Per-IP limit on registration, authorization, token, bind, and MCP. Fail closed if the binding errors. */
export async function enforceRateLimit(
  request: Request,
  env: Env,
  extraHeaders?: HeadersInit,
): Promise<Response | null> {
  if (request.method === 'OPTIONS') return null
  const bucket = rateLimitBucket(new URL(request.url).pathname)
  if (!bucket) return null
  const limiter = bucket === 'mcp' ? env.MCP_RATE_LIMIT : env.AUTH_RATE_LIMIT
  if (!limiter) return json({ error: 'server_misconfigured' }, 503, extraHeaders)
  const ip = request.headers.get('CF-Connecting-IP')?.trim() || 'unknown'
  try {
    const result = await limiter.limit({ key: `${bucket}:${ip}` })
    if (!result.success) {
      return json({ error: 'rate_limited' }, 429, { ...headerRecord(extraHeaders), 'Retry-After': '60' })
    }
  } catch (error) {
    console.error('rate limit failed', error instanceof Error ? error.name : 'error')
    return json({ error: 'server_misconfigured' }, 503, extraHeaders)
  }
  return null
}

function headerRecord(headers?: HeadersInit): Record<string, string> {
  if (!headers) return {}
  if (headers instanceof Headers) {
    const record: Record<string, string> = {}
    headers.forEach((value, key) => { record[key] = value })
    return record
  }
  if (Array.isArray(headers)) return Object.fromEntries(headers)
  return { ...headers }
}
