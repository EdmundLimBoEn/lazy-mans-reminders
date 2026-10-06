function loopbackHost(hostname: string): boolean {
  const host = hostname.toLowerCase()
  return host === 'localhost' || host === '::1' || host === '[::1]' || /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host)
}

/** Allow https, loopback http, and private app schemes. Reject public http and script URLs. */
export function isSafeOauthRedirect(redirectTo: string): boolean {
  try {
    if (redirectTo.includes('\\')) return false
    const url = new URL(redirectTo)
    if (url.username || url.password) return false
    if (url.protocol === 'https:') return true
    if (url.protocol === 'http:') return loopbackHost(url.hostname)
    if (url.protocol === 'javascript:' || url.protocol === 'data:' || url.protocol === 'file:' || url.protocol === 'vbscript:' || url.protocol === 'blob:' || url.protocol === 'mailto:') {
      return false
    }
    return /^[a-z][a-z0-9+.-]*:$/i.test(url.protocol)
  } catch {
    return false
  }
}

export function bindFailureMessage(error: string | undefined): string {
  switch (error) {
    case 'expired_state':
      return 'This link expired. Ask the agent to connect again.'
    case 'unauthorized':
      return 'Sign-in expired. Sign in again in this window, then tap Allow.'
    case 'invalid_state':
      return 'This connect link is not valid. Ask the agent to connect again.'
    case 'untrusted_client':
      return 'This agent is not a registered client anymore. Ask it to connect again.'
    case 'board_not_requested':
      return 'This agent did not ask for board access. Allow stays off.'
    case 'rate_limited':
      return 'Too many attempts. Wait a minute and try again.'
    default:
      return 'Could not connect the agent. Try signing in again.'
  }
}
