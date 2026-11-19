import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const webRoot = join(dirname(fileURLToPath(import.meta.url)), '..')
const read = (path: string) => readFileSync(join(webRoot, path), 'utf8')

describe('canonical host', () => {
  it.each([
    'index.html',
    'public/sitemap.xml',
    'public/robots.txt',
    'public/security.txt',
    'public/.well-known/security.txt',
  ])('%s points at app.notepads.dev, not np.sillyapps.co', (path) => {
    const text = read(path)
    expect(text).toContain('https://app.notepads.dev/')
    expect(text).not.toContain('np.sillyapps.co')
  })

  it('both security.txt copies match', () => {
    expect(read('public/security.txt')).toBe(read('public/.well-known/security.txt'))
  })
})
