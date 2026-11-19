import { Client } from '@modelcontextprotocol/client'
import { InMemoryTransport } from '@modelcontextprotocol/server'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { MCP_RESOURCE } from './constants'
import { handlePublicRequest } from './oauth'
import { createServer } from './server'
import { sessionFromProps } from './session'

const userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const env = {
  SUPABASE_URL: 'https://database.test',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service',
  USAGE_ANALYTICS_ENABLED: 'true',
} as Env
let client: Client
let server: ReturnType<typeof createServer>
const dbFetch = vi.fn(async () => Response.json([]))

beforeEach(async () => {
  vi.stubGlobal('fetch', dbFetch)
  // These are the bound props stored on an approved board grant.
  const session = sessionFromProps({ userId, agentName: 'Test', tokenId: 'oauth' })!
  server = createServer(session, env)
  client = new Client({ name: 'test', version: '1' })
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair()
  await server.connect(serverTransport)
  await client.connect(clientTransport)
})

afterEach(async () => {
  await client.close()
  await server.close()
  vi.unstubAllGlobals()
  dbFetch.mockClear()
})

it('lists only the approved board operations and whoami', async () => {
  const { tools } = await client.listTools()
  expect(tools.map(tool => tool.name).sort()).toEqual([
    'add_reminder', 'complete_reminder', 'list_reminders', 'reopen_reminder', 'whoami',
  ])
})

it('advertises exactly the tools listed for a board grant', async () => {
  const url = new URL('/.well-known/mcp/server-card.json', MCP_RESOURCE)
  const response = await handlePublicRequest(new Request(url), env)
  expect(response.status).toBe(200)

  const card = await response.json<{ tools: string[] }>()
  const { tools } = await client.listTools()
  expect(card.tools.sort()).toEqual(tools.map(tool => tool.name).sort())
})

it('rejects a direct edit call under a board grant before any database writes', async () => {
  const call = client.callTool({ name: 'edit_reminder', arguments: { id: userId, text: 'Corrected' } })
  await expect(call).rejects.toThrow(/Tool edit_reminder not found/)
  expect(dbFetch.mock.calls).toHaveLength(0)
})
