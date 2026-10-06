import { useCallback, useEffect, useState } from 'react'
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
    <div className="connected-agents">
      <h3>Connected agents</h3>
      <p>These finished Allow. Revoke ends that agent’s access to your board.</p>
      {error && <p className="error" role="alert">{error}</p>}
      {grants.length === 0 ? (
        <p className="connected-empty">No connected agents.</p>
      ) : (
        <ul className="agent-token-list" aria-label="Connected agents">
          {grants.map((grant) => (
            <li key={grant.id}>
              <div>
                <strong>{grant.clientName ?? 'Unnamed agent'}</strong>
                {grant.redirectOrigin && <span>Returns to {grant.redirectOrigin}</span>}
              </div>
              <button className="text-button danger-text" type="button" disabled={busy} onClick={() => void revoke(grant.id)}>
                Revoke
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
