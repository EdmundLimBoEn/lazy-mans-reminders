import type { TokenExchangeCallbackOptions } from '@cloudflare/workers-oauth-provider'
import { OAUTH_TOKEN_ID } from './constants'
import type { BoundProps } from './session'
import type { AccountExists } from './supabaseUser'

export type AccountCheck = 'live' | 'deleted' | 'unavailable'

export async function checkAccount(
  env: Env,
  accountExists: AccountExists,
  userId: string,
): Promise<AccountCheck> {
  try {
    return (await accountExists(env, userId)) ? 'live' : 'deleted'
  } catch (error) {
    console.error('account lookup failed', error instanceof Error ? error.name : 'error')
    return 'unavailable'
  }
}

/** Keep the board binding. Drop email and display name from encrypted grant props. */
export function publicGrantProps(props: unknown, userId: string): BoundProps {
  const record = props && typeof props === 'object' ? props as Record<string, unknown> : {}
  const agentName = typeof record.agentName === 'string' && record.agentName.trim()
    ? record.agentName.trim()
    : 'Agent'
  const tokenId = typeof record.tokenId === 'string' && record.tokenId.length > 0
    ? record.tokenId
    : OAUTH_TOKEN_ID
  return { userId, agentName, tokenId }
}

export type TokenDecision =
  | { kind: 'ok'; newProps: BoundProps }
  | { kind: 'unavailable' }
  | { kind: 'deleted' }

/**
 * Decide a token issue or refresh. An outage is `unavailable` and does not
 * revoke. The caller turns `deleted` and `unavailable` into OAuth errors.
 */
export async function decideTokenExchange(
  env: Env,
  accountExists: AccountExists,
  exchange: TokenExchangeCallbackOptions,
  revoke: (grantId: string, userId: string) => Promise<void>,
): Promise<TokenDecision> {
  const status = await checkAccount(env, accountExists, exchange.userId)
  if (status === 'unavailable') return { kind: 'unavailable' }
  if (status === 'deleted') {
    try {
      await revoke(exchange.grantId, exchange.userId)
    } catch (error) {
      console.error('grant revoke after account deletion failed', error instanceof Error ? error.name : 'error')
    }
    return { kind: 'deleted' }
  }
  return { kind: 'ok', newProps: publicGrantProps(exchange.props, exchange.userId) }
}
