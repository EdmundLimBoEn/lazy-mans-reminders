export const MCP_ORIGIN = 'https://lmr-mcp.edmundlim.systems'
export const MCP_URL = `${MCP_ORIGIN}/mcp`
export const RETURN_TO_KEY = 'lmr_return_to'

export function authCallbackUrl(): string {
  return `${window.location.origin}/auth/callback`
}

export function rememberReturnTo(): void {
  const next = `${window.location.pathname}${window.location.search}`
  if (next.startsWith('/connect')) sessionStorage.setItem(RETURN_TO_KEY, next)
}

export function consumeReturnTo(): string {
  const next = sessionStorage.getItem(RETURN_TO_KEY) || '/'
  sessionStorage.removeItem(RETURN_TO_KEY)
  return next.startsWith('/') ? next : '/'
}
