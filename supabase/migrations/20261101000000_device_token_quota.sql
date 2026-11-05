begin;

create function public.enforce_device_token_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Serialize registrations before checking capacity, including ON CONFLICT
  -- upserts, so a waiting registration sees the preceding transaction's rows.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));

  -- Keep four other devices plus the registration being inserted/refreshed.
  -- Excluding its token makes re-registration at capacity a no-op for eviction
  -- and preserves its Live Activity state. Ties have a stable token ordering.
  delete from public.device_tokens
  where user_id = new.user_id and token in (
    select token from public.device_tokens
    where user_id = new.user_id and token <> new.token
    order by updated_at desc, token desc
    offset 4
  );
  return new;
end;
$$;
revoke all on function public.enforce_device_token_quota() from public, anon, authenticated;

create trigger device_tokens_enforce_quota
  before insert or update of user_id on public.device_tokens
  for each row execute function public.enforce_device_token_quota();

commit;
