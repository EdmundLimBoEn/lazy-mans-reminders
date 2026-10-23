-- Server-only leases: device owners must not be able to overwrite a claim.
create table public.live_activity_start_leases (
  device_token text primary key references public.device_tokens(token) on delete cascade,
  lease_id uuid not null,
  expires_at timestamptz not null
);
alter table public.live_activity_start_leases enable row level security;
alter table public.live_activity_start_leases force row level security;
revoke all on public.live_activity_start_leases from public, anon, authenticated;
grant all on public.live_activity_start_leases to service_role;

create function public.claim_live_activity_start(
  p_device_token text, p_user_id uuid, p_lease_id uuid,
  p_expected_token text, p_expected_started_at timestamptz
) returns boolean
language plpgsql set search_path = '' as $$
begin
  -- Serialize with completion and reject snapshots read before another start
  -- completed. Checking only lease expiry would allow those stale handlers in.
  perform 1 from public.device_tokens
    where token = p_device_token and user_id = p_user_id
      and activity_push_token is not distinct from p_expected_token
      and activity_started_at is not distinct from p_expected_started_at
    for update;
  if not found then return false; end if;

  -- Two minutes exceeds the transport's three 10-second attempts plus backoff.
  insert into public.live_activity_start_leases(device_token, lease_id, expires_at)
    values (p_device_token, p_lease_id, clock_timestamp() + interval '2 minutes')
    on conflict (device_token) do update
      set lease_id = excluded.lease_id, expires_at = excluded.expires_at
      where public.live_activity_start_leases.expires_at <= clock_timestamp();
  return found;
end;
$$;

create function public.complete_live_activity_start(
  p_device_token text, p_user_id uuid, p_previous_token text,
  p_started_at timestamptz, p_replacing boolean, p_lease_id uuid
) returns void
language plpgsql set search_path = '' as $$
begin
  perform 1 from public.device_tokens
    where token = p_device_token and user_id = p_user_id for update;
  if not found then return; end if;
  delete from public.live_activity_start_leases
    where device_token = p_device_token and lease_id = p_lease_id
      and expires_at > clock_timestamp();
  if not found then return; end if;
  perform public.record_live_activity_start(
    p_device_token, p_user_id, p_previous_token, p_started_at, p_replacing);
end;
$$;

create function public.release_live_activity_start(
  p_device_token text, p_user_id uuid, p_lease_id uuid
) returns void
language sql set search_path = '' as $$
  delete from public.live_activity_start_leases
    where device_token = p_device_token and lease_id = p_lease_id
      and exists (select 1 from public.device_tokens
        where token = p_device_token and user_id = p_user_id);
$$;

revoke all on function public.claim_live_activity_start(text, uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.complete_live_activity_start(text, uuid, text, timestamptz, boolean, uuid) from public, anon, authenticated;
revoke all on function public.release_live_activity_start(text, uuid, uuid) from public, anon, authenticated;
grant execute on function public.claim_live_activity_start(text, uuid, uuid, text, timestamptz) to service_role;
grant execute on function public.complete_live_activity_start(text, uuid, text, timestamptz, boolean, uuid) to service_role;
grant execute on function public.release_live_activity_start(text, uuid, uuid) to service_role;
