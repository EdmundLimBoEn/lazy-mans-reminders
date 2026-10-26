-- Shared by all Edge Function invocations; separate from start acknowledgement leases.
create table public.device_delivery_slots (
  device_token text primary key references public.device_tokens(token) on delete cascade,
  lease_id uuid not null,
  expires_at timestamptz not null
);
alter table public.device_delivery_slots enable row level security;
alter table public.device_delivery_slots force row level security;
revoke all on public.device_delivery_slots from public, anon, authenticated;
grant all on public.device_delivery_slots to service_role;

create function public.claim_device_delivery(
  p_device_token text, p_user_id uuid, p_lease_id uuid
) returns boolean
language plpgsql set search_path = '' as $$
begin
  perform 1 from public.device_tokens
    where token = p_device_token and user_id = p_user_id for update;
  if not found then return false; end if;
  insert into public.device_delivery_slots(device_token, lease_id, expires_at)
    values (p_device_token, p_lease_id, clock_timestamp() + interval '2 minutes')
    on conflict (device_token) do update
      set lease_id = excluded.lease_id, expires_at = excluded.expires_at
      where public.device_delivery_slots.expires_at <= clock_timestamp();
  return found;
end;
$$;

create function public.release_device_delivery(
  p_device_token text, p_user_id uuid, p_lease_id uuid
) returns void
language sql set search_path = '' as $$
  delete from public.device_delivery_slots
    where device_token = p_device_token and lease_id = p_lease_id
      and exists (select 1 from public.device_tokens
        where token = p_device_token and user_id = p_user_id);
$$;

revoke all on function public.claim_device_delivery(text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.release_device_delivery(text, uuid, uuid) from public, anon, authenticated;
grant execute on function public.claim_device_delivery(text, uuid, uuid) to service_role;
grant execute on function public.release_device_delivery(text, uuid, uuid) to service_role;
