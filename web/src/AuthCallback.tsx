import { useEffect, useState } from 'react'
import {
  pkceCodeFromCallbackUrl,
  pkceFlowIdFromCallbackUrl,
  pkceReturnToFromCallbackUrl,
  safeReturnPath,
} from './pkceCallback'
import { consumeReturnTo } from './mcp'
import { supabase } from './supabase'
import { LegalFooterLinks } from './LegalPages'

function isFlowStateError(message: string): boolean {
  const lower = message.toLowerCase()
  return lower.includes('flow state') || lower.includes('code verifier')
}

export function AuthCallback({ onNavigate }: { onNavigate: (path: string) => void }) {
  const [error, setError] = useState('')
  const [retryHref, setRetryHref] = useState('/')

  useEffect(() => {
    const href = window.location.href
    const params = new URLSearchParams(window.location.search)
    const oauthError = params.get('error_description') || params.get('error')
    const returnTo = safeReturnPath(pkceReturnToFromCallbackUrl(href) || consumeReturnTo())
    if (oauthError) {
      setError(oauthError)
      setRetryHref(returnTo)
      return
    }

    void (async () => {
      const code = pkceCodeFromCallbackUrl(href)
      const flowId = pkceFlowIdFromCallbackUrl(href)

      if (!code) {
        setError('Missing sign-in code. Start sign-in again from the board or connect link.')
        setRetryHref(returnTo)
        return
      }

      const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(
        code,
        flowId ? { flowId } : undefined,
      )
      if (exchangeError) {
        const { data } = await supabase.auth.getSession()
        if (!data.session) {
          setError(
            isFlowStateError(exchangeError.message)
              ? `${exchangeError.message} Start sign-in again so this callback gets a fresh verification code.`
              : exchangeError.message,
          )
          setRetryHref(returnTo)
          return
        }
      }
      // Full navigation keeps /connect?state=…; client navigate() would drop the query.
      window.location.replace(returnTo)
    })()
  }, [])

  if (error) {
    return (
      <main className="fatal-error" role="alert">
        <h1>Could not finish sign-in</h1>
        <p>{error}</p>
        <a className="primary" href={retryHref}>
          {retryHref.startsWith('/connect') ? 'Back to connect' : 'Back to the board'}
        </a>
        <LegalFooterLinks onNavigate={onNavigate} />
      </main>
    )
  }

  return <div className="splash" role="status" aria-label="Finishing sign-in">LM</div>
}
