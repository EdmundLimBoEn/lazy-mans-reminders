const DANGEROUS_PROTOCOLS = new Set([
  'javascript:',
  'data:',
  'vbscript:',
  'file:',
  'mailto:',
  'blob:',
])

/** Same loopback rule as workers-oauth-provider: localhost, ::1, and 127.0.0.0/8. */
export function isLoopbackHost(hostname: string): boolean {
  const host = hostname.toLowerCase()
  if (host === 'localhost' || host === '::1' || host === '[::1]') return true
  return /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host)
}

/**
 * https, loopback http, or a private app scheme such as cursor://.
 * Public http would put the authorization code on the query string in cleartext.
 */
export function redirectUriAllowed(redirectUri: string): boolean {
  if (!redirectUri || redirectUri.includes('\\')) return false
  if (/[\u0000-\u001f\u007f-\u009f]/.test(redirectUri)) return false
  let url: URL
  try {
    url = new URL(redirectUri)
  } catch {
    return false
  }
  if (url.username || url.password) return false
  const protocol = url.protocol.toLowerCase()
  if (DANGEROUS_PROTOCOLS.has(protocol)) return false
  if (protocol === 'https:') return true
  if (protocol === 'http:') return isLoopbackHost(url.hostname)
  return /^[a-z][a-z0-9+.-]*:$/.test(protocol)
}

/** Exact match, or loopback host/path/query match ignoring port. Unsafe URIs never match. */
export function redirectUriRegistered(redirectUri: string, registered: readonly string[]): boolean {
  if (!redirectUriAllowed(redirectUri)) return false
  let requested: URL
  try {
    requested = new URL(redirectUri)
  } catch {
    return false
  }
  return registered.some((candidate) => {
    if (!redirectUriAllowed(candidate)) return false
    if (candidate === redirectUri) return true
    try {
      const reg = new URL(candidate)
      if (requested.protocol !== 'http:' || reg.protocol !== 'http:') return false
      if (!isLoopbackHost(requested.hostname) || !isLoopbackHost(reg.hostname)) return false
      return requested.hostname === reg.hostname
        && requested.pathname === reg.pathname
        && requested.search === reg.search
    } catch {
      return false
    }
  })
}

/** Display origin. Custom schemes have no URL origin, so fall back to scheme and host. */
export function redirectOrigin(redirectUri: string | undefined): string | null {
  if (!redirectUri || !redirectUriAllowed(redirectUri)) return null
  try {
    const url = new URL(redirectUri)
    if (url.origin && url.origin !== 'null') return url.origin
    return url.host ? `${url.protocol}//${url.host}` : url.protocol
  } catch {
    return null
  }
}

/** Reject dynamic registration that asks for a public http redirect. */
export function registrationRedirectError(
  metadata: Record<string, unknown>,
): { description: string } | undefined {
  const uris = metadata.redirect_uris
  if (!Array.isArray(uris) || uris.length === 0 || !uris.every((uri) => typeof uri === 'string')) {
    return { description: 'redirect_uris is required' }
  }
  if (!uris.every((uri) => redirectUriAllowed(uri))) {
    return { description: 'Redirect URI must use https, loopback http, or a private app scheme' }
  }
  return undefined
}
