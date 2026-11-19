import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, it } from 'vitest'

const source = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'Splash.tsx'), 'utf8')

it('keeps the splash mark still when the user asks for reduced motion', () => {
  expect(source).toMatch(/animate-pulse/)
  expect(source).toMatch(/motion-reduce:animate-none/)
})
