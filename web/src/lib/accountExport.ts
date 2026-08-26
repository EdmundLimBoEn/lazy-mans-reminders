export type AccountExportReminder = {
  id: string
  text: string
  sort_order: number
  is_done: boolean
  created_at: string
}

export type AccountExportAgentKey = {
  id: string
  name: string
  created_at: string
  last_used_at: string | null
}

export type AccountExport = {
  exported_at: string
  service: 'lazy-mans-reminders'
  account: {
    email: string | null
    user_id: string
  }
  lock_screen: {
    max_lines: number
  }
  reminders: AccountExportReminder[]
  agent_keys: AccountExportAgentKey[]
}

export function accountExportFilename(now: Date = new Date()): string {
  return `lmr-account-${now.toISOString().slice(0, 10)}.json`
}

export function buildAccountExport(input: {
  exportedAt?: string
  email: string | null
  userId: string
  maxLines: number
  reminders: AccountExportReminder[]
  agentKeys: AccountExportAgentKey[]
}): AccountExport {
  return {
    exported_at: input.exportedAt ?? new Date().toISOString(),
    service: 'lazy-mans-reminders',
    account: {
      email: input.email,
      user_id: input.userId,
    },
    lock_screen: {
      max_lines: input.maxLines,
    },
    reminders: input.reminders,
    agent_keys: input.agentKeys,
  }
}

export function serializeAccountExport(payload: AccountExport): string {
  return `${JSON.stringify(payload, null, 2)}\n`
}
