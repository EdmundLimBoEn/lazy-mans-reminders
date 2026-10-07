export const THEME_STORAGE_KEY = 'lmr-theme'
export const THEME_COLOR = {
  light: '#ffffff',
  dark: '#0a0a0a',
} as const

export type ThemePreference = 'system' | 'light' | 'dark'
export type ResolvedTheme = 'light' | 'dark'

export function isThemePreference(value: unknown): value is ThemePreference {
  return value === 'system' || value === 'light' || value === 'dark'
}

export function resolveTheme(preference: ThemePreference, prefersDark: boolean): ResolvedTheme {
  if (preference === 'light') return 'light'
  if (preference === 'dark') return 'dark'
  return prefersDark ? 'dark' : 'light'
}

export function readStoredPreference(): ThemePreference {
  try {
    const value = window.localStorage.getItem(THEME_STORAGE_KEY)
    if (isThemePreference(value)) return value
  } catch {
    // Private mode can throw; treat as system.
  }
  return 'system'
}

export function prefersDarkScheme(): boolean {
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

/** Class on <html> that turns CSS transitions off while the palette swaps (rule in styles.css). */
export const THEME_SWITCHING_CLASS = 'theme-switching'
let switchToken = 0

export function applyResolvedTheme(theme: ResolvedTheme): void {
  const root = document.documentElement
  // Buttons (transition-all) and toggle items (transition-[color]) would otherwise
  // cross-fade from the old palette to the new one, so for ~150 ms after a switch every
  // control renders grey on grey and looks disabled. Swap with transitions off, flush
  // styles so the new colours land without a transition, and restore them two frames later.
  const token = ++switchToken
  root.classList.add(THEME_SWITCHING_CLASS)
  root.setAttribute('data-theme', theme)
  root.classList.toggle('dark', theme === 'dark')
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', THEME_COLOR[theme])
  void window.getComputedStyle(root).transitionDuration
  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      if (token === switchToken) root.classList.remove(THEME_SWITCHING_CLASS)
    })
  })
}

export function persistPreference(preference: ThemePreference): void {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, preference)
  } catch {
    // Ignore quota / private-mode failures; the in-memory theme still applies.
  }
}
