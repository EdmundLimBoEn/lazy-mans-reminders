import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runInNewContext } from 'node:vm'
import { describe, expect, it } from 'vitest'
import { THEME_COLOR, THEME_STORAGE_KEY, resolveTheme, type ThemePreference } from './theme'

const dir = dirname(fileURLToPath(import.meta.url))
const themeInitSource = readFileSync(join(dir, '../public/theme-init.js'), 'utf8')
const indexHtml = readFileSync(join(dir, '../index.html'), 'utf8')

type InitResult = {
  theme: string | null
  themeColor: string
  wroteStorage: boolean
  setInlineStyle: boolean
}

function runThemeInit(stored: string | null, prefersDark: boolean): InitResult {
  const attrs: Record<string, string> = {}
  const meta = {
    content: THEME_COLOR.light,
    setAttribute(name: string, value: string) {
      if (name === 'content') this.content = value
    },
  }
  let wroteStorage = false
  let setInlineStyle = false
  const document = {
    documentElement: {
      setAttribute(name: string, value: string) {
        attrs[name] = value
      },
      getAttribute(name: string) {
        return attrs[name] ?? null
      },
      style: new Proxy(
        {},
        {
          set() {
            setInlineStyle = true
            return true
          },
        },
      ),
    },
    querySelector(selector: string) {
      return selector === 'meta[name="theme-color"]' ? meta : null
    },
  }
  const window = {
    localStorage: {
      getItem() {
        return stored
      },
      setItem() {
        wroteStorage = true
      },
    },
    matchMedia(query: string) {
      return { matches: query.includes('prefers-color-scheme: dark') ? prefersDark : false }
    },
    document,
  }
  runInNewContext(themeInitSource, { window, document })
  return {
    theme: attrs['data-theme'] ?? null,
    themeColor: meta.content,
    wroteStorage,
    setInlineStyle,
  }
}

describe('theme-init.js first paint', () => {
  it('is a render-blocking classic script in <head>, not module/defer/async', () => {
    expect(indexHtml).toMatch(/<head>[\s\S]*<script src="\/theme-init\.js"><\/script>[\s\S]*<\/head>/)
    expect(indexHtml).not.toMatch(/theme-init\.js"[^>]*\bdefer\b/)
    expect(indexHtml).not.toMatch(/theme-init\.js"[^>]*\basync\b/)
    expect(indexHtml).not.toMatch(/theme-init\.js"[^>]*type="module"/)
    expect(indexHtml).not.toMatch(/<script(?![^>]*src=)[^>]*>/)
  })

  it('applies synchronously with no paint-delaying APIs', () => {
    expect(themeInitSource).not.toMatch(/requestAnimationFrame/)
    expect(themeInitSource).not.toMatch(/DOMContentLoaded/)
    expect(themeInitSource).not.toMatch(/addEventListener/)
    expect(themeInitSource).not.toMatch(/setTimeout/)
    expect(themeInitSource).not.toMatch(/\.style\b/)
  })

  it('shares the storage key and theme-color values with the React helper', () => {
    expect(themeInitSource).toContain(`'${THEME_STORAGE_KEY}'`)
    expect(themeInitSource).toContain(`'${THEME_COLOR.light}'`)
    expect(themeInitSource).toContain(`'${THEME_COLOR.dark}'`)
  })

  it.each([
    ['light', true, 'light'],
    ['dark', false, 'dark'],
    ['system', true, 'dark'],
    ['system', false, 'light'],
    [null, true, 'dark'],
    [null, false, 'light'],
    ['not-a-theme', true, 'dark'],
    ['not-a-theme', false, 'light'],
  ] as const)('stored %s + prefersDark=%s → data-theme=%s', (stored, prefersDark, expected) => {
    const result = runThemeInit(stored, prefersDark)
    const preference: ThemePreference =
      stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system'
    expect(result.theme).toBe(expected)
    expect(result.theme).toBe(resolveTheme(preference, prefersDark))
    expect(result.themeColor).toBe(THEME_COLOR[expected])
    expect(result.wroteStorage).toBe(false)
    expect(result.setInlineStyle).toBe(false)
  })

  it('falls back to the media query when localStorage throws', () => {
    const attrs: Record<string, string> = {}
    const document = {
      documentElement: {
        setAttribute(name: string, value: string) {
          attrs[name] = value
        },
      },
      querySelector() {
        return null
      },
    }
    const window = {
      localStorage: {
        getItem() {
          throw new Error('blocked')
        },
      },
      matchMedia() {
        return { matches: true }
      },
      document,
    }
    runInNewContext(themeInitSource, { window, document })
    expect(attrs['data-theme']).toBe('dark')
  })
})
