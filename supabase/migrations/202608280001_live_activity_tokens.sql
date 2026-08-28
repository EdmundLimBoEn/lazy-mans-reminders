-- ActivityKit push-to-start / update tokens live on the same device row as the
-- alert APNs token. Hex length is unbounded-from-64 because ActivityKit tokens
-- are not the 32-byte alert device token.

alter table public.device_tokens
  add column push_to_start_token text
    check (
      push_to_start_token is null
      or push_to_start_token ~ '^[0-9A-Fa-f]{64,}$'
    ),
  add column activity_push_token text
    check (
      activity_push_token is null
      or activity_push_token ~ '^[0-9A-Fa-f]{64,}$'
    ),
  add column activity_started_at timestamptz;
