import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'

const minimumVersions = new Map([
  ['@modelcontextprotocol/server', '2.3.0'],
  ['@modelcontextprotocol/client', '2.3.0'],
  ['@modelcontextprotocol/sdk', '1.32.0'],
  ['zod', '4.6.6'],
  ['hono', '4.13.16'],
])

it('keeps all locked MCP runtime dependencies at or above their patched versions', () => {
  const { packages } = JSON.parse(readFileSync(new URL('../package-lock.json', import.meta.url), 'utf8')) as {
    packages: Record<string, { name?: string; version?: string }>
  }

  for (const [path, entry] of Object.entries(packages)) {
    const installedName = path.match(/(?:^|\/)node_modules\/((?:@[^/]+\/)?[^/]+)$/)?.[1]
    if (!installedName) continue
    const floor = minimumVersions.get(entry.name ?? installedName)
    if (!floor) continue
    const [, release, prerelease] = entry.version?.match(/^(\d+\.\d+\.\d+)(-[\w.-]+)?(?:\+[\w.-]+)?$/) ?? []
    const order = release?.localeCompare(floor, 'en', { numeric: true }) ?? -1
    expect(order > 0 || (order === 0 && !prerelease), `${path} resolves to ${entry.version}, expected ${floor} or newer`).toBe(true)
  }
})
