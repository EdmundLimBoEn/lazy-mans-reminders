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
  return next.startsWith('/') && !next.startsWith('//') ? next : '/'
}
