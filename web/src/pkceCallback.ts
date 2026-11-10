/** Read a callback query or hash param. Never pass the full href to exchangeCodeForSession. */
export function pkceParamFromCallbackUrl(href: string, name: string): string | null {
  try {
    const url = new URL(href)
    const fromQuery = url.searchParams.get(name)
    if (fromQuery) return fromQuery
    const hash = new URLSearchParams(url.hash.startsWith('#') ? url.hash.slice(1) : '')
    return hash.get(name)
  } catch {
    return null
  }
}

export function pkceCodeFromCallbackUrl(href: string): string | null {
  return pkceParamFromCallbackUrl(href, 'code')
}

export function pkceFlowIdFromCallbackUrl(href: string): string | null {
  return pkceParamFromCallbackUrl(href, 'sb_flow_id')
}

export function pkceReturnToFromCallbackUrl(href: string): string | null {
  return pkceParamFromCallbackUrl(href, 'return_to')
}

const SITE_ORIGIN = 'https://app.notepads.dev'

/** Only allow a same-origin relative path. Backslash and encoded slash/backslash forms are rejected. */
export function safeReturnPath(
  candidate: string | null | undefined,
  fallback = '/',
  siteOrigin = SITE_ORIGIN,
): string {
  if (!candidate) return fallback
  if (!candidate.startsWith('/') || candidate.startsWith('//')) return fallback
  if (candidate.includes('\\') || /%(?:5c|2f)/i.test(candidate)) return fallback
  let base: URL
  let resolved: URL
  try {
    base = new URL(siteOrigin)
    resolved = new URL(candidate, base)
  } catch {
    return fallback
  }
  if (resolved.origin !== base.origin) return fallback
  if (!resolved.pathname.startsWith('/') || resolved.username || resolved.password) return fallback
  const returned = `${resolved.pathname}${resolved.search}${resolved.hash}`
  // Dot-segment normalization can turn `/.//evil.example` into `//evil.example`,
  // which location.replace and <a href> treat as a protocol-relative URL.
  if (!returned.startsWith('/') || returned.startsWith('//')) return fallback
  try {
    if (new URL(returned, base).origin !== base.origin) return fallback
  } catch {
    return fallback
  }
  return returned
}
