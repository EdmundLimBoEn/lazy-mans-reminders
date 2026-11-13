import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'

it('links the landing page to the released iOS app without a coming-soon placeholder', () => {
  const html = readFileSync(new URL('../../landing/index.html', import.meta.url), 'utf8')

  expect(html).toMatch(/<a\b[^>]*href="https:\/\/apps\.apple\.com\/app\/id6799138197"[^>]*>/)
  expect(html).not.toMatch(/coming\s+soon/i)
})
