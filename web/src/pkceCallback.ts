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

/** Only allow same-origin relative paths so a forged redirect cannot leave the site. */
export function safeReturnPath(candidate: string | null | undefined, fallback = '/'): string {
  if (!candidate) return fallback
  if (!candidate.startsWith('/') || candidate.startsWith('//')) return fallback
  return candidate
}
