export type AppRoute = '/' | '/privacy' | '/terms' | '/support' | '/auth/callback' | '/connect'

/** Normalize a pathname to a known app route (strip trailing slashes; unknown → `/`). */
export function normalizePath(pathname: string): AppRoute {
  const path = pathname.replace(/\/+$/, '') || '/'
  if (
    path === '/privacy'
    || path === '/terms'
    || path === '/support'
    || path === '/auth/callback'
    || path === '/connect'
  ) {
    return path
  }
  return '/'
}
