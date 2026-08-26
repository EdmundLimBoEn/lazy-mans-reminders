export const MCP_HOST = 'lmr-mcp.edmundlim.systems'
export const MCP_RESOURCE = `https://${MCP_HOST}/mcp`
export const OAUTH_TOKEN_ID = 'oauth'
export const PENDING_AUTH_TTL_SECONDS = 600

export const TOOLS = [
  'list_reminders',
  'add_reminder',
  'complete_reminder',
  'reopen_reminder',
  'whoami',
] as const
