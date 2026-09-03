import { safeReturnPath } from './pkceCallback'

export const MCP_ORIGIN = 'https://lmr-mcp.edmundlim.systems'
export const MCP_URL = `${MCP_ORIGIN}/mcp`
export const RETURN_TO_KEY = 'lmr_return_to'

/** Placeholder only. Never put a real agent key in source, snippets, or tests. */
export const AGENT_TOKEN_PLACEHOLDER = 'TOKEN'
export const LMR_AGENT_TOKEN_VAR = 'LMR_AGENT_TOKEN'

export function cursorMcpConfig(url: string): string {
  return `{
  "mcpServers": {
    "lazy-mans-reminders": {
      "url": "${url}"
    }
  }
}`
}

export function claudeMcpConfig(url: string): string {
  return `{
  "mcpServers": {
    "lazy-mans-reminders": {
      "type": "http",
      "url": "${url}"
    }
  }
}`
}

export function grokConnectorConfig(url: string): string {
  return `URL: ${url}
Authorization: Bearer ${AGENT_TOKEN_PLACEHOLDER}`
}

export function lmrAgentTokenHeaderTemplate(): string {
  return `Authorization: Bearer \${${LMR_AGENT_TOKEN_VAR}}`
}

/** Persist /connect?state=… across OAuth so AuthCallback can return to Allow. */
export function connectReturnTo(pathname: string, search = ''): string | null {
  if (pathname !== '/connect') return null
  return `${pathname}${search}`
}

export function authCallbackUrlFrom(origin: string, pathname: string, search = ''): string {
  const url = new URL('/auth/callback', origin)
  const returnTo = connectReturnTo(pathname, search)
  if (returnTo) url.searchParams.set('return_to', returnTo)
  return url.toString()
}

export function authCallbackUrl(): string {
  return authCallbackUrlFrom(window.location.origin, window.location.pathname, window.location.search)
}

export function rememberReturnTo(): void {
  const next = connectReturnTo(window.location.pathname, window.location.search)
  if (!next) return
  try {
    sessionStorage.setItem(RETURN_TO_KEY, next)
  } catch {
    // Private mode can throw; return_to on the callback URL is the durable path.
  }
}

export function consumeReturnTo(): string {
  let stored = '/'
  try {
    stored = sessionStorage.getItem(RETURN_TO_KEY) || '/'
    sessionStorage.removeItem(RETURN_TO_KEY)
  } catch {
    stored = '/'
  }
  return safeReturnPath(stored, '/')
}
