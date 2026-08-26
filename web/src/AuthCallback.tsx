import { useEffect, useState } from 'react'
import { consumeReturnTo } from './mcp'
import { supabase } from './supabase'
import { LegalFooterLinks } from './LegalPages'

export function AuthCallback({ onNavigate }: { onNavigate: (path: string) => void }) {
  const [error, setError] = useState('')

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const oauthError = params.get('error_description') || params.get('error')
    if (oauthError) {
      setError(oauthError)
      return
    }

    void (async () => {
      const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(window.location.href)
      if (exchangeError) {
        const { data } = await supabase.auth.getSession()
        if (!data.session) {
          setError(exchangeError.message)
          return
        }
      }
      window.location.replace(consumeReturnTo())
    })()
  }, [])

  if (error) {
    return (
      <main className="fatal-error" role="alert">
        <h1>Could not finish sign-in</h1>
        <p>{error}</p>
        <a className="primary" href="/">Back to the board</a>
        <LegalFooterLinks onNavigate={onNavigate} />
      </main>
    )
  }

  return <div className="splash" role="status" aria-label="Finishing sign-in">LM</div>
}
