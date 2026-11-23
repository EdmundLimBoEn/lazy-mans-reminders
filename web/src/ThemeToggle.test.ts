// @vitest-environment happy-dom
import { createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import { ThemeToggle } from './ThemeToggle'
import { THEME_STORAGE_KEY } from './theme'

it('updates the selection and palette when another tab changes or clears the theme', async () => {
  const container = document.createElement('div')
  const root = createRoot(container)
  const storage = window.localStorage
  const notify = (key: string | null) => {
    window.dispatchEvent(Object.assign(new Event('storage'), { key, storageArea: storage }))
  }
  const expectSelection = async (label: string, theme: string) => {
    await vi.waitFor(() => {
      expect(container.querySelector(`[aria-label="${label}"]`)?.getAttribute('data-state')).toBe('on')
      expect(document.documentElement.dataset.theme).toBe(theme)
    })
  }

  try {
    storage.setItem(THEME_STORAGE_KEY, 'light')
    root.render(createElement(ThemeToggle))
    await expectSelection('Light', 'light')
    storage.setItem(THEME_STORAGE_KEY, 'dark')
    notify(THEME_STORAGE_KEY)
    await expectSelection('Dark', 'dark')
    storage.clear()
    notify(null)
    await expectSelection('System', window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    expect(storage.getItem(THEME_STORAGE_KEY)).toBeNull()
  } finally {
    root.unmount()
    storage.removeItem(THEME_STORAGE_KEY)
  }
})
