/** Allow http(s) and custom schemes used by agent hosts. Reject javascript/data/file. */
export function isSafeOauthRedirect(redirectTo: string): boolean {
  try {
    const url = new URL(redirectTo)
    if (url.protocol === 'https:' || url.protocol === 'http:') return true
    if (url.protocol === 'javascript:' || url.protocol === 'data:' || url.protocol === 'file:' || url.protocol === 'vbscript:') {
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
    default:
      return 'Could not connect the agent. Try signing in again.'
  }
}
