import { afterEach, describe, expect, it, vi } from 'vitest'
import { applyResolvedTheme, THEME_COLOR } from './theme'

function fakeDocument() {
  const attrs: Record<string, string> = {}
  const classes = new Set<string>()
  const meta = { content: '', setAttribute: (_: string, value: string) => { meta.content = value } }
  const doc = {
    documentElement: {
      setAttribute: (name: string, value: string) => { attrs[name] = value },
      classList: {
        toggle: (name: string, force?: boolean) => {
          const on = force ?? !classes.has(name)
          if (on) classes.add(name)
          else classes.delete(name)
          return on
        },
      },
    },
    querySelector: (selector: string) => (selector === 'meta[name="theme-color"]' ? meta : null),
  }
  return { doc, attrs, classes, meta }
}

describe('applyResolvedTheme (runtime toggle)', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('keeps data-theme, the .dark class and theme-color in step when switching', () => {
    const { doc, attrs, classes, meta } = fakeDocument()
    vi.stubGlobal('document', doc)

    applyResolvedTheme('dark')
    expect([attrs['data-theme'], classes.has('dark'), meta.content]).toEqual(['dark', true, THEME_COLOR.dark])

    applyResolvedTheme('light')
    expect([attrs['data-theme'], classes.has('dark'), meta.content]).toEqual(['light', false, THEME_COLOR.light])
  })
})
