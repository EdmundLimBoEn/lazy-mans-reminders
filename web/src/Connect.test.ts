// @vitest-environment happy-dom
import type { Session } from '@supabase/supabase-js'
import { act, createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import { Connect } from './Connect'
import { MCP_ORIGIN } from './mcp'

it.each(['valid', 'expired'] as const)('rechecks consent on reconnect when the request is %s', async (result) => {
  const session = { access_token: 'test-token', user: { email: 'test@example.com' } } as Session
  const summary = {
    client: { name: 'Test agent' },
    redirectOrigin: 'https://agent.example',
    permissions: ['read', 'add', 'complete', 'reopen'],
  }
  const fetchConsent = vi.fn()
    .mockRejectedValueOnce(new TypeError('Offline'))
    .mockResolvedValueOnce(result === 'valid'
      ? Response.json({ summary })
      : Response.json({ error: 'expired_state' }, { status: 400 }))
  vi.stubGlobal('fetch', fetchConsent)
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true)
  window.history.replaceState({}, '', '/connect?state=test-state')
  const container = document.createElement('div')
  const root = createRoot(container)
  try {
    await act(async () => root.render(createElement(Connect, { session, onNavigate: vi.fn() })))
    const allow = container.querySelector<HTMLButtonElement>('button[type="submit"]')!
    expect(allow.disabled).toBe(true)
    expect(container.querySelector('[role="alert"]')?.textContent).toContain('Could not reach')

    await act(async () => { window.dispatchEvent(new Event('online')) })
    expect(fetchConsent).toHaveBeenCalledTimes(2)
    expect(fetchConsent).toHaveBeenLastCalledWith(`${MCP_ORIGIN}/consent?state=test-state`, {
      headers: { Authorization: 'Bearer test-token' },
    })
    expect(allow.disabled).toBe(result === 'expired')
    const alert = container.querySelector('[role="alert"]')
    if (result === 'expired') expect(alert?.textContent).toContain('expired')
    else expect(alert).toBeNull()

    await act(async () => { window.dispatchEvent(new Event('online')) })
    expect(fetchConsent).toHaveBeenCalledTimes(2)
  } finally {
    await act(() => root.unmount())
    window.history.replaceState({}, '', '/')
    vi.unstubAllGlobals()
  }
})
