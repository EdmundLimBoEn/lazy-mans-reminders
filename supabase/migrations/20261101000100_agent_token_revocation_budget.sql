begin;

-- Keep credential removal available after content writes exhaust the budget.
-- CREATE OR REPLACE preserves the existing trigger function's restricted ACL.
create or replace function public.enforce_user_write_budget() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid;
  window_start timestamptz := pg_catalog.date_trunc('minute', statement_timestamp());
begin
  owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  -- Account deletion cascades must remain possible even with an exhausted budget.
  if tg_op = 'DELETE' and not exists (select 1 from auth.users where id = owner_id) then
    return null;
  end if;

  if tg_table_schema = 'public' and tg_table_name = 'agent_tokens'
      and owner_id = (select auth.uid()) then
    if tg_op = 'DELETE' then
      return null;
    elsif tg_op = 'UPDATE' then
      -- Only an active-to-revoked transition with no other changes is exempt.
      if old.revoked_at is null and new.revoked_at is not null
          and (to_jsonb(old) - 'revoked_at') = (to_jsonb(new) - 'revoked_at') then
        return null;
      end if;
    end if;
  end if;

  -- ON CONFLICT locks the user's counter and rechecks the limit after waiting,
  -- so concurrent transactions cannot spend the same remaining capacity.
  insert into public.user_write_budgets as budget(user_id, window_started_at, writes)
  values (owner_id, window_start, 1)
  on conflict (user_id) do update
    set window_started_at = greatest(budget.window_started_at, excluded.window_started_at),
        writes = case when budget.window_started_at < excluded.window_started_at
          then 1 else budget.writes + 1 end
    where budget.window_started_at < excluded.window_started_at or budget.writes < 600;
  if not found then
    raise exception using errcode = 'P0001', message = 'rate_limited';
  end if;
  return null;
end;
$$;

commit;
