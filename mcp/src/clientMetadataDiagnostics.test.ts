import { inspect } from 'node:util'
import { CimdFetchError } from '@cloudflare/workers-oauth-provider'
import { afterEach, expect, it, vi } from 'vitest'
import { setup } from '../test/oauthWorker'
import { MCP_HOSTS } from './constants'

afterEach(() => {
  vi.restoreAllMocks()
  vi.unstubAllGlobals()
})

it.each([
  ['userinfo', 'https://user:fixture-password@metadata.example/client.json', false],
  ['signed query', 'https://metadata.example/client.json?sig=fixture-signature', true],
] as const)('redacts %s from metadata lookup warnings and exceptions', async (_kind, clientId, shouldFetch) => {
  vi.stubGlobal('Cloudflare', { compatibilityFlags: { global_fetch_strictly_public: true } })
  const fetch = vi.fn(async () => { throw new Error('fixture-origin-error') })
  vi.stubGlobal('fetch', fetch)
  const warnings = vi.spyOn(console, 'warn').mockImplementation(() => {})
  const { request } = setup()

  const token = await request(MCP_HOSTS[0], '/token', {
    method: 'POST',
    body: new URLSearchParams({ grant_type: 'authorization_code', client_id: clientId }),
  })
  expect(token.status).toBe(401)
  expect(await token.json()).toMatchObject({ error: 'invalid_client', error_description: 'Client not found' })
  const params = new URLSearchParams({ response_type: 'code', client_id: clientId })
  const failure = await request(MCP_HOSTS[0], `/authorize?${params}`).catch((error: unknown) => error)
  expect(failure).toBeInstanceOf(CimdFetchError)
  expect(fetch).toHaveBeenCalledTimes(shouldFetch ? 2 : 0)
  expect(warnings).toHaveBeenCalledWith('metadata_resolution_failed')
  const sensitive = /metadata\.example|fixture-password|fixture-signature|fixture-origin-error/
  expect(inspect(warnings.mock.calls)).not.toMatch(sensitive)
  expect(inspect(failure)).not.toMatch(sensitive)
})
