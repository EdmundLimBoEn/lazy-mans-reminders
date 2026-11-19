// @vitest-environment happy-dom
import { createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'

vi.mock('./supabase', () => ({
  authStorageKey: 'test-auth',
  supabase: { auth: {
    getSession: async () => ({ data: { session: null }, error: null }),
    onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
  } },
}))

it('offers a reload after a rejected Privacy download and renders Privacy on a fresh load', async () => {
  window.history.replaceState({}, '', '/privacy')
  const reload = vi.spyOn(window.location, 'reload').mockImplementation(() => {})
  const uncaught = vi.fn()
  const container = document.createElement('div')
  const mount = () => createRoot(container, { onCaughtError: vi.fn(), onUncaughtError: uncaught })
  let root = mount()
  vi.doMock('./LegalPages', () => { throw new TypeError('Route download failed') })
  try {
    const { default: App } = await import('./App')
    root.render(createElement(App))
    const retry = await vi.waitFor(() => {
      const button = container.querySelector<HTMLButtonElement>('[role="alert"] button')
      expect(button?.textContent).toBe('Try again')
      return button!
    })
    retry.click()
    expect(reload).toHaveBeenCalledOnce()

    // A document reload gives React.lazy a fresh module and import promise.
    root.unmount()
    vi.doUnmock('./LegalPages')
    vi.resetModules()
    root = mount()
    const { default: FreshApp } = await import('./App')
    root.render(createElement(FreshApp))
    await vi.waitFor(() => expect(container.querySelector('h1')?.textContent).toBe('Privacy Policy'))
    expect(uncaught).not.toHaveBeenCalled()
  } finally {
    root.unmount()
    vi.doUnmock('./LegalPages')
    reload.mockRestore()
  }
})
