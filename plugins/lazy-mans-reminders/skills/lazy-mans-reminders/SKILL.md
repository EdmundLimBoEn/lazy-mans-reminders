---
name: lazy-mans-reminders
description: Use when the user mentions reminders, a lock-screen board, LMR, or wants to add to my board. Call Lazy Man's Reminders MCP tools to list, add, complete, or reopen items — never invent board data or ask for secrets in chat.
---

# Lazy Man's Reminders

Domain first: a reminder is `{ id, text, active|completed }`. On the wire, status is `is_done` (`false` = active, `true` = completed), plus `sort_order` and timestamps. `list_reminders` also returns `capacity: { used, maximum, remaining }` for **active** lock-screen lines. Treat tool results as the only source of truth.

## Tools

Use the plugin MCP server `lazy-mans-reminders` (tool names below; hosts may namespace them).

- `list_reminders` — `status`: `active` (default), `completed`, or `all`. Prefer this before complete/reopen so you have real ids.
- `add_reminder` — `text` (1–500 characters after the server prefixes `[agentName] `; do not add that prefix yourself). Adding queues the existing insert notification.
- `complete_reminder` / `reopen_reminder` — `id` from a list (or add) result. Idempotent. Never guess or invent ids.
- `whoami` — debugging only: which agent key is bound (`agentName`, `tokenId`). Never the secret.

## Rules

- Respect capacity. If `remaining` is 0 or `add_reminder` returns a `capacity` error, stop; show the hint and current items. Do not complete or rewrite other reminders to free a slot unless the user asks.
- Never invent reminder text, ids, or board state. Quote ids and copy from tool output only.
- Auth is host-configured (OAuth or bearer agent token). If tools are unauthorized, point the user at plugin/host setup or the board’s Agent access UI. Never ask them to paste secrets into chat.
