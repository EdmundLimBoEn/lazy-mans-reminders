import { useEffect, useState } from 'react'
import {
  pkceCodeFromCallbackUrl,
  pkceFlowIdFromCallbackUrl,
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
    const params = new URLSearchParams(window.location.search)
    const oauthError = params.get('error_description') || params.get('error')
    if (oauthError) {
      setError(oauthError)
      setRetryHref(safeReturnPath(params.get('return_to') || consumeReturnTo()))
      return
    }

    void (async () => {
      const href = window.location.href
      const code = pkceCodeFromCallbackUrl(href)
      const flowId = pkceFlowIdFromCallbackUrl(href)
      const returnTo = safeReturnPath(params.get('return_to') || consumeReturnTo())

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
              ? `${exchangeError.message} Finish sign-in in the same browser window that started it. For Grok, open the connect link in Safari or Chrome, sign in there, then tap Allow.`
              : exchangeError.message,
          )
          setRetryHref(returnTo)
          return
        }
      }
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
