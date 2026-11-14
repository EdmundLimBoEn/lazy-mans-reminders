import { createServiceRoleClient } from './auth'

type AgentUsageEvent = 'mcp_list' | 'mcp_add' | 'mcp_edit' | 'mcp_complete' | 'mcp_reopen' |
  'mcp_whoami' | 'agent_oauth_connected'

/** Best effort, bounded, and off unless both Worker and database flags are enabled. */
export async function recordAgentUsage(env: Env, userId: string, event: AgentUsageEvent): Promise<void> {
  if (env.USAGE_ANALYTICS_ENABLED !== 'true') return
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 1000)
  try {
    await createServiceRoleClient(env).rpc('record_agent_usage', {
      p_user_id: userId,
      p_event: event,
    }).abortSignal(controller.signal)
  } catch {
    // No content, credentials or user identifiers in analytics failure logs.
    // Missing migration, network failure or retention races must not block MCP.
  } finally {
    clearTimeout(timer)
  }
}
