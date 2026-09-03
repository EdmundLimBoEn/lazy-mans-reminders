import { describe, expect, it } from 'vitest'
import {
  AGENT_TOKEN_PLACEHOLDER,
  LMR_AGENT_TOKEN_VAR,
  MCP_URL,
  authCallbackUrlFrom,
  claudeMcpConfig,
  connectReturnTo,
  cursorMcpConfig,
  grokConnectorConfig,
  lmrAgentTokenHeaderTemplate,
} from './mcp'

describe('agent MCP snippets', () => {
  it('shows Grok with the URL and a header placeholder, never a real secret', () => {
    const snippet = grokConnectorConfig(MCP_URL)
    expect(snippet).toContain(`URL: ${MCP_URL}`)
    expect(snippet).toContain(`Authorization: Bearer ${AGENT_TOKEN_PLACEHOLDER}`)
    expect(snippet).not.toMatch(/url only/i)
    expect(snippet).not.toMatch(/lmr__/)
    expect(AGENT_TOKEN_PLACEHOLDER).toBe('TOKEN')
  })

  it('keeps Cursor and Claude snippets on the OAuth URL path', () => {
    expect(cursorMcpConfig(MCP_URL)).toContain(`"url": "${MCP_URL}"`)
    expect(cursorMcpConfig(MCP_URL)).not.toMatch(/Authorization/)
    expect(claudeMcpConfig(MCP_URL)).toContain('"type": "http"')
    expect(claudeMcpConfig(MCP_URL)).not.toMatch(/Authorization/)
  })

  it('names the plugin variable without embedding a token', () => {
    expect(LMR_AGENT_TOKEN_VAR).toBe('LMR_AGENT_TOKEN')
    expect(lmrAgentTokenHeaderTemplate()).toBe(`Authorization: Bearer \${${LMR_AGENT_TOKEN_VAR}}`)
    expect(lmrAgentTokenHeaderTemplate()).not.toMatch(/lmr__/)
  })
})

describe('connectReturnTo', () => {
  it('keeps the connect path and query, and ignores other routes', () => {
    expect(connectReturnTo('/connect', '?state=abc')).toBe('/connect?state=abc')
    expect(connectReturnTo('/connect')).toBe('/connect')
    expect(connectReturnTo('/')).toBeNull()
    expect(connectReturnTo('/privacy')).toBeNull()
  })
})

describe('authCallbackUrlFrom', () => {
  it('puts return_to on the callback URL so a new tab can still finish Allow', () => {
    expect(
      authCallbackUrlFrom('https://lmr.edmundlim.systems', '/connect', '?state=abc'),
    ).toBe(
      'https://lmr.edmundlim.systems/auth/callback?return_to=%2Fconnect%3Fstate%3Dabc',
    )
  })

  it('leaves homepage sign-in callbacks clean', () => {
    expect(authCallbackUrlFrom('https://lmr.edmundlim.systems', '/')).toBe(
      'https://lmr.edmundlim.systems/auth/callback',
    )
  })
})
