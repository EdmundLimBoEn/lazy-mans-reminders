import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
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
  it('keeps plugin manifests on the same canonical MCP URL the board advertises', () => {
    expect(MCP_URL).toBe('https://np-mcp.sillyapps.co/mcp')
    const root = join(dirname(fileURLToPath(import.meta.url)), '../..')
    for (const relative of [
      'plugins/lazy-mans-reminders/mcp.json',
      'plugins/lazy-mans-reminders/.cursor-plugin/mcp.json',
    ]) {
      const manifest = JSON.parse(readFileSync(join(root, relative), 'utf8')) as {
        mcpServers: { 'lazy-mans-reminders': { url: string } }
      }
      expect(manifest.mcpServers['lazy-mans-reminders'].url).toBe(MCP_URL)
    }
  })

  it('shows Grok the OAuth URL without a bearer header', () => {
    const snippet = grokConnectorConfig(MCP_URL)
    expect(snippet).toContain('URL: https://np-mcp.sillyapps.co/mcp')
    expect(snippet).not.toMatch(/Authorization/)
    expect(snippet).not.toMatch(/lmr__/)
    expect(AGENT_TOKEN_PLACEHOLDER).toBe('TOKEN')
  })

  it('keeps Cursor and Claude snippets on the OAuth URL path', () => {
    expect(cursorMcpConfig(MCP_URL)).toContain('"url": "https://np-mcp.sillyapps.co/mcp"')
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
  it.each([
    'https://np.sillyapps.co',
    'https://lmr.sillyapps.co',
  ])('puts return_to on the callback URL for %s so a new tab can still finish Allow', (origin) => {
    expect(authCallbackUrlFrom(origin, '/connect', '?state=abc')).toBe(
      `${origin}/auth/callback?return_to=%2Fconnect%3Fstate%3Dabc`,
    )
  })

  it('leaves homepage sign-in callbacks clean', () => {
    expect(authCallbackUrlFrom('https://np.sillyapps.co', '/')).toBe(
      'https://np.sillyapps.co/auth/callback',
    )
  })
})
