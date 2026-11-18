import type { MouseEventHandler } from 'react'

export type AppRoute =
  | '/'
  | '/privacy'
  | '/terms'
  | '/support'
  | '/auth/callback'
  | '/auth/ios'
  | '/connect'
  | 'not-found'

const KNOWN = new Set<AppRoute>([
  '/',
  '/privacy',
  '/terms',
  '/support',
  '/auth/callback',
  '/auth/ios',
  '/connect',
])

/** Normalize a pathname to a known app route. Case-insensitive. Unknown → not-found. */
export function normalizePath(pathname: string): AppRoute {
  const stripped = pathname.replace(/\/+$/, '') || '/'
  const path = (stripped === '/' ? '/' : stripped.replace(/\/{2,}/g, '/')).toLowerCase() as AppRoute
  if (KNOWN.has(path)) return path
  return 'not-found'
}

export function navigateOnClick(onNavigate: (path: string) => void, path: string): MouseEventHandler<HTMLAnchorElement> {
  return event => {
    if (event.defaultPrevented || event.button !== 0 || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return

    event.preventDefault()
    onNavigate(path)
  }
}
