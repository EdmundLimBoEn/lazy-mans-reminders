export const MCP_HOST = 'mcp.notepads.dev'
export const MCP_HOSTS = [MCP_HOST, 'np-mcp.sillyapps.co', 'lmr-mcp.edmundlim.systems'] as const
export const MCP_RESOURCE = `https://${MCP_HOST}/mcp`

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
export function mcpResourceMetadataForRequest(request: Request): string {
  return new URL('/.well-known/oauth-protected-resource/mcp', mcpResourceForRequest(request)).href
}

export const OAUTH_TOKEN_ID = 'oauth'
export const PENDING_AUTH_TTL_SECONDS = 600

export const TOOLS = [
  'list_reminders',
  'add_reminder',
  'edit_reminder',
  'complete_reminder',
  'reopen_reminder',
  'whoami',
] as const
