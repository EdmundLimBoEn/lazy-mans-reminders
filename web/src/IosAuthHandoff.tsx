import { Button } from '@/components/ui/button'
import { StatusShell, StatusText } from '@/components/StatusShell'
import { iosHandoffFromLocation } from './iosHandoff'

export function IosAuthHandoff({ onNavigate }: { onNavigate: (path: string) => void }) {
  const result = iosHandoffFromLocation(window.location.href)

  if (result.status === 'error') {
    return (
      <StatusShell title="Could not finish sign-in" role="alert" onNavigate={onNavigate}>
        <StatusText>{result.message}</StatusText>
        <Button asChild className="mt-3">
          <a
            href="/"
            onClick={(event) => {
              event.preventDefault()
              onNavigate('/')
            }}
          >
            Back to the board
          </a>
        </Button>
      </StatusShell>
    )
  }

  if (result.status === 'empty') {
    return (
      <StatusShell title="This sign-in link is incomplete" role="alert" onNavigate={onNavigate}>
        <StatusText>Return to Lazy Man's Reminders on this iPhone and request a new email link.</StatusText>
      </StatusShell>
    )
  }

  return (
    <StatusShell title="Open the app to finish" role="status" onNavigate={onNavigate}>
      <StatusText>
        Email sign-in has to finish inside Lazy Man's Reminders. Tap below to hand this link to the
        app on this iPhone.
      </StatusText>
      <Button asChild className="mt-3">
        <a href={result.href}>Open Lazy Man's Reminders</a>
      </Button>
    </StatusShell>
  )
}
