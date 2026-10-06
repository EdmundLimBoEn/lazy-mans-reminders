import type { TokenExchangeCallbackOptions } from '@cloudflare/workers-oauth-provider'
import { describe, expect, it } from 'vitest'
import { decideTokenExchange, publicGrantProps } from './accountGate'

const exchange = {
  grantType: 'refresh_token',
  clientId: 'client-a',
  userId: 'user-a',
  grantId: 'grant-a-aaaaaaaa',
  scope: ['board'],
  requestedScope: ['board'],
  props: {
    userId: 'user-a',
    tokenId: 'oauth',
    agentName: 'Grok',
    userEmail: 'hidden@example.com',
    userName: 'Hidden Name',
  },
} as TokenExchangeCallbackOptions

describe('onTokenExchange', () => {
  it('strips stored identity and leaves a live grant in place', async () => {
    const revoked: string[] = []
    const result = await decideTokenExchange(
      {} as Env,
      async () => true,
      exchange,
      async (grantId) => { revoked.push(grantId) },
    )
    expect(result).toEqual({
      kind: 'ok',
      newProps: { userId: 'user-a', tokenId: 'oauth', agentName: 'Grok' },
    })
    if (result.kind === 'ok') {
      expect(result.newProps).not.toHaveProperty('userEmail')
      expect(result.newProps).not.toHaveProperty('userName')
    }
    expect(revoked).toEqual([])
    expect(publicGrantProps(exchange.props, exchange.userId)).not.toHaveProperty('userEmail')
  })

  it('revokes a deleted account and does not revoke when lookup fails', async () => {
    const revoked: string[] = []
    await expect(decideTokenExchange(
      {} as Env,
      async () => false,
      exchange,
      async (grantId, userId) => { revoked.push(`${userId}:${grantId}`) },
    )).resolves.toEqual({ kind: 'deleted' })
    expect(revoked).toEqual(['user-a:grant-a-aaaaaaaa'])

    revoked.length = 0
    await expect(decideTokenExchange(
      {} as Env,
      async () => { throw new Error('supabase down') },
      exchange,
      async (grantId) => { revoked.push(grantId) },
    )).resolves.toEqual({ kind: 'unavailable' })
    expect(revoked).toEqual([])
  })
})
