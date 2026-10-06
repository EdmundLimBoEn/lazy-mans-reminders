const BOARD_PERMISSIONS = ['read', 'add', 'complete', 'reopen'] as const

export type ConsentSummary = {
  client: { name: string | null }
  redirectOrigin: string
  permissions: string[]
}

export function consentCanApprove(summary: ConsentSummary | null): boolean {
  if (!summary) return false
  if (!originLooksDisplayable(summary.redirectOrigin)) return false
  return BOARD_PERMISSIONS.every((permission) => summary.permissions.includes(permission))
}

export function parseConsentSummary(body: unknown): ConsentSummary | null {
  if (!body || typeof body !== 'object') return null
  const summary = (body as { summary?: unknown }).summary
  if (!summary || typeof summary !== 'object') return null
  const record = summary as {
    client?: { name?: unknown }
    redirectOrigin?: unknown
    permissions?: unknown
  }
  if (typeof record.redirectOrigin !== 'string' || !originLooksDisplayable(record.redirectOrigin)) return null
  const name = record.client && typeof record.client.name === 'string' ? record.client.name : null
  const permissions = Array.isArray(record.permissions)
    ? record.permissions.filter((permission): permission is string => typeof permission === 'string')
    : []
  return {
    client: { name },
    redirectOrigin: record.redirectOrigin,
    permissions,
  }
}

function originLooksDisplayable(value: string): boolean {
  if (!value || value.includes('\\')) return false
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    if (code < 0x20 || code === 0x7f) return false
  }
  try {
    const url = new URL(value.includes('://') ? value : `${value}//placeholder`)
    return url.protocol !== 'javascript:' && url.protocol !== 'data:' && url.protocol !== 'file:'
  } catch {
    return false
  }
}

export function permissionSentence(permissions: readonly string[]): string {
  const labels: Record<string, string> = {
    read: 'read your board',
    add: 'add reminders',
    complete: 'mark them complete',
    reopen: 'reopen them',
  }
  const parts = permissions.map((permission) => labels[permission]).filter((label): label is string => Boolean(label))
  if (parts.length === 0) return 'It did not ask for any board access.'
  if (parts.length === 1) return `It can ${parts[0]}.`
  return `It can ${parts.slice(0, -1).join(', ')}, and ${parts[parts.length - 1]}.`
}
