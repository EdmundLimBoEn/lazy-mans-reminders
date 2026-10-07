import { useCallback, useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { parseGrantList, type GrantView } from './grantList'
import { MCP_ORIGIN } from './mcp'

export function ConnectedAgents({ accessToken }: { accessToken: string }) {
  const [grants, setGrants] = useState<GrantView[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const response = await fetch(`${MCP_ORIGIN}/grants`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    const body = await response.json().catch(() => null)
    const parsed = parseGrantList(body)
    if (!response.ok || !parsed) {
      setError('Could not load connected agents.')
      return
    }
    setError('')
    setGrants(parsed)
  }, [accessToken])

  useEffect(() => { void load().catch(() => setError('Could not load connected agents.')) }, [load])

  async function revoke(id: string) {
    if (busy) return
    setBusy(true)
    setError('')
    try {
      const response = await fetch(`${MCP_ORIGIN}/grants/revoke`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ grantId: id }),
      })
      if (!response.ok) {
        setError('Could not revoke that agent.')
        return
      }
      await load()
    } catch {
      setError('Could not reach the agent connector.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="connected-agents flex flex-col gap-3">
      <div className="space-y-1">
        <h3 className="text-sm font-medium">Connected agents</h3>
        <p className="text-sm text-muted-foreground">These finished Allow. Revoke ends that agent’s access to your board.</p>
      </div>
      {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
      {grants.length === 0 ? (
        <p className="connected-empty rounded-lg border border-dashed px-3 py-4 text-center text-sm text-muted-foreground">No connected agents.</p>
      ) : (
        <ul className="agent-token-list divide-y rounded-lg border" aria-label="Connected agents">
          {grants.map((grant) => (
            <li key={grant.id} className="flex items-center justify-between gap-4 py-2 pr-2 pl-3">
              <div className="grid min-w-0 gap-0.5">
                <strong className="truncate text-sm font-medium">{grant.clientName ?? 'Unnamed agent'}</strong>
                {grant.redirectOrigin && <span className="truncate text-xs text-muted-foreground">Returns to {grant.redirectOrigin}</span>}
              </div>
              <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" type="button" disabled={busy} onClick={() => void revoke(grant.id)}>
                Revoke
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
