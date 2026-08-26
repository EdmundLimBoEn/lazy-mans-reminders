import { describe, expect, it } from 'vitest'
import { sessionFromProps } from './session'

describe('sessionFromProps', () => {
  it('builds a session from OAuth props', () => {
    expect(sessionFromProps({ userId: 'user-1', agentName: 'Grok' })).toEqual({
      userId: 'user-1',
      tokenId: 'oauth',
      agentName: 'Grok',
    })
  })

  it('rejects missing user ids', () => {
    expect(sessionFromProps({})).toBeNull()
    expect(sessionFromProps(null)).toBeNull()
  })
})
