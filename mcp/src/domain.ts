export type UserId = string & { readonly __brand: 'UserId' }
export type TokenId = string & { readonly __brand: 'TokenId' }
export type TokenSecret = string & { readonly __brand: 'TokenSecret' }
export type TokenHash = string & { readonly __brand: 'TokenHash' }

export type PresentedToken = { tokenId: TokenId; secret: TokenSecret }

export type AgentSession = { userId: UserId; tokenId: TokenId; agentName: string }

export type ReminderStatus = 'active' | 'completed'

export type BoardCommand =
  | { kind: 'list'; status: ReminderStatus | 'all' }
  | { kind: 'add'; text: string }
  | { kind: 'complete'; reminderId: string }
  | { kind: 'reopen'; reminderId: string }

export type Capacity = {
  used: number
  maximum: number
  remaining: number
}

export type BoardError =
  | { kind: 'unauthorized' }
  | { kind: 'not_found' }
  | { kind: 'capacity'; maxLines: number; hint: string; snapshot: BoardSnapshot }
  | { kind: 'invalid_text' }
  | { kind: 'storage'; message: string }

export type ReminderRow = {
  id: string
  text: string
  is_done: boolean
  sort_order: number
  created_at: string
  completed_at: string | null
}

export type BoardSnapshot = {
  reminders: ReminderRow[]
  capacity: Capacity
}

export type BoardOk =
  | { kind: 'snapshot'; snapshot: BoardSnapshot }
  | { kind: 'written'; reminder: ReminderRow; capacity: Capacity }
  | { kind: 'changed'; reminder: ReminderRow }

export type BoardResult = BoardOk | BoardError

export type PrefixResult =
  | { kind: 'ok'; text: string }
  | { kind: 'invalid_text' }
