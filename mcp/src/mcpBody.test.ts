import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createMcpHandler } from 'agents/mcp/server'
import { setup } from '../test/oauthWorker'
import { hashSecret } from './token'
import type { TokenSecret } from './domain'

// Exercise the real provider and MCP transport, spying only on handler creation.
vi.mock('agents/mcp/server', async (importOriginal) => {
  const actual = await importOriginal<typeof import('agents/mcp/server')>()
  return { ...actual, createMcpHandler: vi.fn(actual.createMcpHandler) }
})

const HOST = 'np-mcp.sillyapps.co'
const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
const LIMIT = 1024 * 1024
const headers = {
  Host: HOST,
  Authorization: `Bearer lmr_${USER}_test-secret`,
  'Content-Type': 'application/json',
  Accept: 'application/json, text/event-stream',
}

beforeEach(async () => {
  const token_hash = await hashSecret('test-secret' as TokenSecret)
  vi.stubGlobal('fetch', async (_input: unknown, init?: RequestInit) => init?.method === 'PATCH'
    ? new Response(null, { status: 204 })
    : Response.json({ id: USER, user_id: USER, name: 'Test', token_hash, revoked_at: null }))
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.clearAllMocks()
})

describe('authenticated MCP body limit', () => {
  it.each([
    ['/mcp', undefined], ['/mcp', '1'], ['/mcp/', undefined], ['/mcp/', '1'],
  ] as const)('rejects oversized streamed %s bodies with Content-Length %s before the handler runs', async (path, contentLength) => {
    const { request, deps } = setup()
    let consumed = 0
    const cancel = vi.fn()
    const chunk = new TextEncoder().encode('é'.repeat(2048))
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (consumed === 2 * LIMIT) return controller.close()
        controller.enqueue(chunk)
        consumed += chunk.byteLength
      },
      cancel,
    }, { highWaterMark: 0 })
    const requestHeaders = new Headers(headers)
    if (contentLength) requestHeaders.set('Content-Length', contentLength)
    const response = await request(HOST, path, {
      method: 'POST', headers: requestHeaders, body, duplex: 'half',
    } as RequestInit)

    expect(response.status).toBe(413)
    expect(await response.json()).toEqual({ error: 'invalid_body' })
    expect(response.headers.get('Content-Type')).toBe('application/json')
    expect(response.headers.get('Cache-Control')).toBe('no-store')
    expect(deps.accountExists).toHaveBeenCalledOnce()
    expect(consumed).toBe(LIMIT + chunk.byteLength)
    expect(cancel).toHaveBeenCalledOnce()
    expect(createMcpHandler).not.toHaveBeenCalled()
  })

  it.each(['/mcp', '/mcp/'])('accepts normal and exactly-at-limit initialization requests on %s', async (path) => {
    const { request } = setup()
    const message = JSON.stringify({
      jsonrpc: '2.0', id: 1, method: 'initialize',
      params: {
        protocolVersion: '2025-03-26', capabilities: {},
        clientInfo: { name: 'body-limit-test', version: '1.0.0' },
      },
    })
    for (const body of [message, message.padEnd(LIMIT, ' ')]) {
      const response = await request(HOST, path, { method: 'POST', headers, body })
      expect(response.status).toBe(200)
      const text = await response.text()
      const data = response.headers.get('Content-Type')?.includes('text/event-stream')
        ? text.split('\n').find((line) => line.startsWith('data: '))!.slice(6)
        : text
      expect(JSON.parse(data)).toMatchObject({
        jsonrpc: '2.0', id: 1,
        result: { serverInfo: { name: 'notepad', version: '1.0.0' } },
      })
    }
    expect(createMcpHandler).toHaveBeenCalledTimes(2)
  })
})


it.each([undefined, 'Bearer invalid-token'])('rejects an edit call with invalid authentication (%s)', async (authorization) => {
  const { request } = setup()
  const requestHeaders = new Headers(headers)
  requestHeaders.delete('Authorization')
  if (authorization) requestHeaders.set('Authorization', authorization)
  const response = await request(HOST, '/mcp', {
    method: 'POST', headers: requestHeaders,
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call',
      params: { name: 'edit_reminder', arguments: { id: USER, text: 'Corrected' } } }),
  })
  expect(response.status).toBe(401)
  expect(createMcpHandler).not.toHaveBeenCalled()
})
