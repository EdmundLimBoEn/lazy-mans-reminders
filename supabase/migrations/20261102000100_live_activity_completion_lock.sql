-- Preserve the RPC's grants and serialize device writers while allowing the
-- push-job foreign key check to proceed when a reminder writer holds the budget.
create or replace function public.complete_live_activity_start(
  p_device_token text, p_user_id uuid, p_previous_token text,
  p_started_at timestamptz, p_replacing boolean, p_lease_id uuid
) returns void
language plpgsql set search_path = '' as $$
begin
  perform 1 from public.device_tokens
    where token = p_device_token and user_id = p_user_id for no key update;
  if not found then return; end if;
  delete from public.live_activity_start_leases
    where device_token = p_device_token and lease_id = p_lease_id
      and expires_at > clock_timestamp();
  if not found then return; end if;
  perform public.record_live_activity_start(
    p_device_token, p_user_id, p_previous_token, p_started_at, p_replacing);
end;
$$;
