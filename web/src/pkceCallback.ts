/** Extract the Supabase PKCE auth code from a callback URL. Never pass the full href to exchangeCodeForSession. */
export function pkceCodeFromCallbackUrl(href: string): string | null {
  try {
    const url = new URL(href)
    const fromQuery = url.searchParams.get('code')
    if (fromQuery) return fromQuery
    const hash = new URLSearchParams(url.hash.startsWith('#') ? url.hash.slice(1) : '')
    return hash.get('code')
  } catch {
    return null
  }
}

export function pkceFlowIdFromCallbackUrl(href: string): string | null {
  try {
    const url = new URL(href)
    return url.searchParams.get('sb_flow_id')
  } catch {
    return null
  }
}

/** Only allow same-origin relative paths so a forged redirect cannot leave the site. */
export function safeReturnPath(candidate: string | null | undefined, fallback = '/'): string {
  if (!candidate) return fallback
  if (!candidate.startsWith('/') || candidate.startsWith('//')) return fallback
  return candidate
}
