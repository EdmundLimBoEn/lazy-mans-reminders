export type GrantView = {
  id: string
  clientName: string | null
  redirectOrigin: string | null
  createdAt: number
  expiresAt: number | null
}

export function parseGrantList(body: unknown): GrantView[] | null {
  if (!body || typeof body !== 'object') return null
  const grants = (body as { grants?: unknown }).grants
  if (!Array.isArray(grants)) return null
  const parsed: GrantView[] = []
  for (const grant of grants) {
    if (!grant || typeof grant !== 'object') return null
    const record = grant as Record<string, unknown>
    if (typeof record.id !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(record.id)) return null
    parsed.push({
      id: record.id,
      clientName: typeof record.clientName === 'string' ? record.clientName : null,
      redirectOrigin: typeof record.redirectOrigin === 'string' ? record.redirectOrigin : null,
      createdAt: typeof record.createdAt === 'number' ? record.createdAt : 0,
      expiresAt: typeof record.expiresAt === 'number' ? record.expiresAt : null,
    })
  }
  return parsed
}
