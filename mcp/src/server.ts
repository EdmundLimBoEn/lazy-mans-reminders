import { McpServer } from '@modelcontextprotocol/server'
import { z } from 'zod'
import type { AgentSession, BoardError, BoardResult, ReminderRow } from './domain'
import { createServiceRoleClient } from './auth'
import { runBoardCommand } from './board'

export function createServer(session: AgentSession, env: Env): McpServer {
  const server = new McpServer({
    name: 'lazy-mans-reminders',
    version: '1.0.0',
  })
  const supabase = createServiceRoleClient(env)

  server.registerTool(
    'list_reminders',
    {
      description: 'List reminders on the signed-in owner board. Defaults to active items.',
      inputSchema: {
        status: z.enum(['active', 'completed', 'all']).optional(),
      },
    },
    async ({ status }) => {
      const result = await runBoardCommand(supabase, session, {
        kind: 'list',
        status: status ?? 'active',
      })
      return toToolResult(result)
    },
  )

  server.registerTool(
    'add_reminder',
    {
      description: 'Add a reminder. The owner is pinged by the existing insert notification.',
      inputSchema: {
        text: z.string(),
      },
    },
    async ({ text }) => {
      const result = await runBoardCommand(supabase, session, { kind: 'add', text })
      return toToolResult(result)
    },
  )

  server.registerTool(
    'complete_reminder',
    {
      description: 'Mark a reminder complete. Idempotent.',
      inputSchema: {
        id: z.string(),
      },
    },
    async ({ id }) => {
      const result = await runBoardCommand(supabase, session, {
        kind: 'complete',
        reminderId: id,
      })
      return toToolResult(result)
    },
  )

  server.registerTool(
    'reopen_reminder',
    {
      description: 'Mark a reminder active again. Idempotent.',
      inputSchema: {
        id: z.string(),
      },
    },
    async ({ id }) => {
      const result = await runBoardCommand(supabase, session, {
        kind: 'reopen',
        reminderId: id,
      })
      return toToolResult(result)
    },
  )

  server.registerTool(
    'whoami',
    {
      description: 'Return the bound agent name and token id, never the secret.',
      inputSchema: {},
    },
    async () => ({
      content: [{
        type: 'text' as const,
        text: JSON.stringify({ agentName: session.agentName, tokenId: session.tokenId }),
      }],
    }),
  )

  return server
}

function toToolResult(result: BoardResult) {
  if (result.kind === 'snapshot') {
    const payload = {
      reminders: result.snapshot.reminders.map(toView),
      capacity: result.snapshot.capacity,
    }
    return { content: [{ type: 'text' as const, text: JSON.stringify(payload) }] }
  }
  if (result.kind === 'written') {
    const payload = {
      reminder: toView(result.reminder),
      capacity: result.capacity,
      notification: 'queued_by_insert',
    }
    return { content: [{ type: 'text' as const, text: JSON.stringify(payload) }] }
  }
  if (result.kind === 'changed') {
    return {
      content: [{ type: 'text' as const, text: JSON.stringify({ reminder: toView(result.reminder) }) }],
    }
  }
  return {
    isError: true,
    content: [{ type: 'text' as const, text: boardErrorText(result) }],
  }
}

function boardErrorText(error: BoardError): string {
  switch (error.kind) {
    case 'unauthorized':
      return 'Unauthorized'
    case 'not_found':
      return 'Reminder not found'
    case 'capacity':
      return JSON.stringify({
        error: 'capacity',
        maxLines: error.maxLines,
        hint: error.hint,
        capacity: error.snapshot.capacity,
        reminders: error.snapshot.reminders.map((row) => ({
          id: row.id,
          text: row.text,
        })),
      })
    case 'invalid_text':
      return 'Text must be 1–500 characters after the agent name prefix'
    case 'storage':
      return error.message
    default: {
      const _exhaustive: never = error
      return _exhaustive
    }
  }
}

function toView(row: ReminderRow) {
  return {
    id: row.id,
    text: row.text,
    is_done: row.is_done,
    sort_order: row.sort_order,
    created_at: row.created_at,
    completed_at: row.completed_at,
  }
}
