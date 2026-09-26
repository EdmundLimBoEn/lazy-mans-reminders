alter table public.device_tokens
  add column retiring_activity_push_token text
  check (
    retiring_activity_push_token is null
    or retiring_activity_push_token ~ '^[0-9A-Fa-f]{64,}$'
  );

-- Preserve a replacement token uploaded while the start push was in flight.
-- Keep the old token until the phone acknowledges the replacement, or the
-- board empties, so accepting a push can never dismiss the current banner.
create function public.record_live_activity_start(
  p_device_token text,
  p_user_id uuid,
  p_previous_token text,
  p_started_at timestamptz,
  p_replacing boolean
) returns void
language sql
set search_path = ''
as $$
  update public.device_tokens
  set activity_started_at = p_started_at,
      retiring_activity_push_token = case
        when p_replacing then p_previous_token
        else retiring_activity_push_token
      end,
      activity_push_token = case
        when activity_push_token is not distinct from p_previous_token then null
        else activity_push_token
      end
  where token = p_device_token and user_id = p_user_id;
$$;

revoke all on function public.record_live_activity_start(text, uuid, text, timestamptz, boolean)
  from public, anon, authenticated;
grant execute on function public.record_live_activity_start(text, uuid, text, timestamptz, boolean)
  to service_role;
