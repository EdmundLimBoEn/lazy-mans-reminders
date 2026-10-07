import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { applyResolvedTheme, THEME_COLOR } from './theme'

const css = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'styles.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')

/**
 * The class that styles.css uses to switch transitions off: a rule whose selector list
 * covers `.<class> *` and whose body is `transition: none !important`.
 */
function transitionSuppressionClass(): string | null {
  for (const match of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    if (!/transition\s*:\s*none\s*!important/.test(match[2])) continue
    const descendant = /\.([\w-]+)\s+\*(?![:\w])/.exec(match[1])
    if (descendant) return descendant[1]
  }
  return null
}

/**
 * Minimal model of how a browser decides to run a CSS transition: a transition starts
 * when a style recalc sees a colour change while transitions are enabled. Recalcs happen
 * on getComputedStyle() and at the end of every rendered frame.
 */
function fakeBrowser(suppressionClass: string | null) {
  const attrs: Record<string, string> = {}
  const classes = new Set<string>()
  const meta = { content: '', setAttribute: (_: string, value: string) => { meta.content = value } }
  const recalcs: { dark: boolean; transitionsOff: boolean }[] = []
  let frameQueue: FrameRequestCallback[] = []
  const recalc = () => recalcs.push({
    dark: classes.has('dark'),
    transitionsOff: suppressionClass !== null && classes.has(suppressionClass),
  })
  const root = {
    setAttribute: (name: string, value: string) => { attrs[name] = value },
    classList: {
      add: (name: string) => { classes.add(name) },
      remove: (name: string) => { classes.delete(name) },
      contains: (name: string) => classes.has(name),
      toggle: (name: string, force?: boolean) => {
        const on = force ?? !classes.has(name)
        if (on) classes.add(name)
        else classes.delete(name)
        return on
      },
    },
  }
  vi.stubGlobal('document', {
    documentElement: root,
    querySelector: (selector: string) => (selector === 'meta[name="theme-color"]' ? meta : null),
  })
  vi.stubGlobal('window', {
    getComputedStyle: () => { recalc(); return { transitionDuration: '0s' } },
    requestAnimationFrame: (cb: FrameRequestCallback) => { frameQueue.push(cb); return frameQueue.length },
  })
  const renderFrames = (count: number) => {
    for (let i = 0; i < count; i += 1) {
      const callbacks = frameQueue
      frameQueue = []
      callbacks.forEach((cb) => cb(i * 16))
      recalc()
    }
  }
  /** Recalcs that saw the palette change while transitions were still enabled. */
  const crossFades = () => recalcs.filter((r, i) => i > 0 && r.dark !== recalcs[i - 1].dark && !r.transitionsOff).length
  return { attrs, classes, meta, recalc, renderFrames, crossFades }
}

describe('applyResolvedTheme (runtime toggle)', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('styles.css has a rule that switches transitions off under a root class', () => {
    expect(transitionSuppressionClass()).not.toBeNull()
  })

  it('keeps data-theme, the .dark class and theme-color in step when switching', () => {
    const browser = fakeBrowser(transitionSuppressionClass())
    applyResolvedTheme('dark')
    expect([browser.attrs['data-theme'], browser.classes.has('dark'), browser.meta.content]).toEqual(['dark', true, THEME_COLOR.dark])
    applyResolvedTheme('light')
    expect([browser.attrs['data-theme'], browser.classes.has('dark'), browser.meta.content]).toEqual(['light', false, THEME_COLOR.light])
  })

  it.each(['dark', 'light'] as const)('swaps to %s without cross-fading controls through grey', (target) => {
    const suppression = transitionSuppressionClass()
    const browser = fakeBrowser(suppression)
    applyResolvedTheme(target === 'dark' ? 'light' : 'dark')
    browser.renderFrames(3) // settled on the starting palette

    applyResolvedTheme(target)
    browser.renderFrames(3)

    expect(browser.crossFades()).toBe(0)
    expect(browser.classes.has('dark')).toBe(target === 'dark')
    // Transitions come back afterwards (hover and focus still animate).
    expect(suppression !== null && browser.classes.has(suppression)).toBe(false)
  })

  it('survives rapid back-to-back switches within one frame', () => {
    const suppression = transitionSuppressionClass()
    const browser = fakeBrowser(suppression)
    applyResolvedTheme('light')
    browser.renderFrames(3)

    applyResolvedTheme('dark')
    browser.renderFrames(1)
    applyResolvedTheme('light')
    applyResolvedTheme('dark')
    browser.renderFrames(4)

    expect(browser.crossFades()).toBe(0)
    expect(browser.classes.has('dark')).toBe(true)
    expect(suppression !== null && browser.classes.has(suppression)).toBe(false)
  })
})
