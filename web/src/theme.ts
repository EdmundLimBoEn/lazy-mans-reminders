export const THEME_STORAGE_KEY = 'lmr-theme'
export const THEME_COLOR = {
  light: '#f5f1e8',
  dark: '#171614',
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

export function applyResolvedTheme(theme: ResolvedTheme): void {
  document.documentElement.setAttribute('data-theme', theme)
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', THEME_COLOR[theme])
}

export function persistPreference(preference: ThemePreference): void {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, preference)
  } catch {
    // Ignore quota / private-mode failures; the in-memory theme still applies.
  }
}
