begin;

create function public.lock_device_token_registration() returns trigger
language plpgsql set search_path = '' as $$
begin
  -- Serialize registrations, including upserts, before writing the device row.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  return new;
end;
$$;
revoke all on function public.lock_device_token_registration() from public, anon, authenticated;

create trigger device_tokens_lock_registration
  before insert or update of user_id on public.device_tokens
  for each row when (
    case current_user
      when 'anon' then false
      when 'authenticated' then new.user_id = auth.uid()
      else true
    end
  )
  execute function public.lock_device_token_registration();

create or replace function public.enforce_device_token_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- A previous row's AFTER trigger may have evicted this row in a bulk write.
  if not exists (select 1 from public.device_tokens
    where user_id = new.user_id and token = new.token) then
    return null;
  end if;

  delete from public.device_tokens
  where user_id = new.user_id and token in (
    select token from public.device_tokens
    where user_id = new.user_id and token <> new.token
    order by updated_at desc, token desc
    offset 4
  );
  return null;
end;
$$;

-- AFTER triggers run in name order. aaa_enforce_write_budget must take the
-- budget lock first, as reminder writes do before locking devices to queue pushes.
create or replace trigger device_tokens_enforce_quota
  after insert or update of user_id on public.device_tokens
  for each row execute function public.enforce_device_token_quota();

commit;
