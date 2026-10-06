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
})
