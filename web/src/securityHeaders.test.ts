import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

describe('pages security headers', () => {
  const headers = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../public/_headers'), 'utf8')

  it('pins HSTS without subdomains and narrows Supabase connect-src', () => {
    expect(headers).toContain('Strict-Transport-Security: max-age=15552000')
    expect(headers).not.toContain('includeSubDomains')
    expect(headers).not.toContain('preload')
    expect(headers).toContain('https://biwmsxbqrevtjwgsvsmu.supabase.co')
    expect(headers).toContain('wss://biwmsxbqrevtjwgsvsmu.supabase.co')
    expect(headers).not.toContain('https://*.supabase.co')
  })

  it('keeps script-src and style-src self-only', () => {
    expect(headers).toMatch(/script-src 'self'/)
    expect(headers).toMatch(/style-src 'self'/)
    expect(headers).not.toContain("'unsafe-inline'")
    expect(headers).not.toContain("'unsafe-eval'")
  })

  it('detaches the Pages default Access-Control-Allow-Origin: * for every path', () => {
    // Cloudflare Pages adds `Access-Control-Allow-Origin: *` to static assets by default.
    // Nothing on this origin is read cross-origin (MCP/OAuth discovery lives on the
    // lmr-mcp Worker), so the `/*` block must remove it and no rule may add it back.
    const blocks = headers.split(/\n(?=\S)/)
    const all = blocks.find((block) => block.startsWith('/*\n'))
    expect(all).toBeDefined()
    expect(all).toMatch(/^ {2}! Access-Control-Allow-Origin$/m)
    expect(headers).not.toMatch(/^\s*Access-Control-Allow-Origin\s*:/im)
  })
})
