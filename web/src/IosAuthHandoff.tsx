import { iosHandoffFromLocation } from './iosHandoff'
import { LegalFooterLinks } from './LegalPages'

export function IosAuthHandoff({ onNavigate }: { onNavigate: (path: string) => void }) {
  const result = iosHandoffFromLocation(window.location.href)

  if (result.status === 'error') {
    return (
      <main className="fatal-error" role="alert">
        <h1>Could not finish sign-in</h1>
        <p>{result.message}</p>
        <a
          className="primary"
          href="/"
          onClick={(event) => {
            event.preventDefault()
            onNavigate('/')
          }}
        >
          Back to the board
        </a>
        <LegalFooterLinks onNavigate={onNavigate} />
      </main>
    )
  }

  if (result.status === 'empty') {
    return (
      <main className="fatal-error" role="alert">
        <h1>This sign-in link is incomplete</h1>
        <p>Return to Lazy Man's Reminders on this iPhone and request a new email link.</p>
        <LegalFooterLinks onNavigate={onNavigate} />
      </main>
    )
  }

  return (
    <main className="fatal-error" role="status">
      <h1>Open the app to finish</h1>
      <p>
        Email sign-in has to finish inside Lazy Man's Reminders. Tap below to hand this link to the
        app on this iPhone.
      </p>
      <a className="primary" href={result.href}>Open Lazy Man's Reminders</a>
      <LegalFooterLinks onNavigate={onNavigate} />
    </main>
  )
}
