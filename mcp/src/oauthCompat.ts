const DISCOVERY_ALIASES: Record<string, string> = {
  '/.well-known/oauth-authorization-server/mcp': '/.well-known/oauth-authorization-server',
  '/.well-known/openid-configuration': '/.well-known/oauth-authorization-server',
  '/.well-known/openid-configuration/mcp': '/.well-known/oauth-authorization-server',
}

export function rewriteOauthPath(pathname: string): string {
  const stripped = pathname.replace(/\/+$/, '') || '/'
  return DISCOVERY_ALIASES[stripped] ?? stripped
}

function isJsonContentType(value: string | null): boolean {
  if (!value) return false
  return value.split(';')[0].trim().toLowerCase() === 'application/json'
}

function oauthFormFromJson(body: unknown): URLSearchParams | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null
  const form = new URLSearchParams()
  for (const [key, value] of Object.entries(body as Record<string, unknown>)) {
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      form.set(key, String(value))
    } else if (Array.isArray(value) && value.every((item) => typeof item === 'string')) {
      form.set(key, value.join(' '))
    }
  }
  return form
}

function withPath(request: Request, pathname: string): Request {
  const url = new URL(request.url)
  if (url.pathname === pathname) return request
  url.pathname = pathname
  return new Request(url, request)
}

/** Map Grok/MCP discovery aliases, trailing slashes, and JSON token posts onto the provider's routes. */
export async function prepareOauthRequest(request: Request): Promise<Request> {
  const rewritten = withPath(request, rewriteOauthPath(new URL(request.url).pathname))
  const path = new URL(rewritten.url).pathname
  if (request.method !== 'POST' || path !== '/token' || !isJsonContentType(rewritten.headers.get('Content-Type'))) {
    return rewritten
  }

  let body: unknown
  try {
    body = await rewritten.json()
  } catch {
    return rewritten
  }
  const form = oauthFormFromJson(body)
  if (!form) return rewritten

  const headers = new Headers(rewritten.headers)
  headers.set('Content-Type', 'application/x-www-form-urlencoded')
  headers.delete('Content-Length')
  return new Request(rewritten.url, {
    method: 'POST',
    headers,
    body: form.toString(),
  })
}
