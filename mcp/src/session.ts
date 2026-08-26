import type { AgentSession, TokenId, UserId } from './domain'
import { OAUTH_TOKEN_ID } from './constants'

export type BoundProps = {
  userId: string
  agentName: string
  tokenId?: string
}

export function sessionFromProps(props: unknown): AgentSession | null {
  if (!props || typeof props !== 'object') return null
  const bound = props as BoundProps
  if (typeof bound.userId !== 'string' || bound.userId.length === 0) return null
  const agentName = typeof bound.agentName === 'string' && bound.agentName.trim() !== ''
    ? bound.agentName.trim()
    : 'Agent'
  const tokenId = typeof bound.tokenId === 'string' && bound.tokenId.length > 0
    ? bound.tokenId
    : OAUTH_TOKEN_ID
  return {
    userId: bound.userId as UserId,
    tokenId: tokenId as TokenId,
    agentName,
  }
}
