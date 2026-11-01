export const MCP_HOST = 'np-mcp.sillyapps.co'
export const MCP_HOSTS = [MCP_HOST, 'lmr-mcp.edmundlim.systems'] as const
export const MCP_RESOURCE = `https://${MCP_HOST}/mcp`
export const MCP_RESOURCE_METADATA = `https://${MCP_HOST}/.well-known/oauth-protected-resource/mcp`

export function mcpResourceForRequest(request: Request): string {
  try {
    const hostname = new URL(request.url).hostname
    if ((MCP_HOSTS as readonly string[]).includes(hostname)) {
      return `https://${hostname}/mcp`
    }
  } catch {
    return MCP_RESOURCE
  }
  return MCP_RESOURCE
}
export const MCP_WWW_AUTHENTICATE =
  `Bearer realm="OAuth", resource_metadata="${MCP_RESOURCE_METADATA}", scope="board"`
export const OAUTH_TOKEN_ID = 'oauth'
export const PENDING_AUTH_TTL_SECONDS = 600

export const TOOLS = [
  'list_reminders',
  'add_reminder',
  'complete_reminder',
  'reopen_reminder',
  'whoami',
] as const
