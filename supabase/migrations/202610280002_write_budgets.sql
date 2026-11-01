begin;

-- One shared budget across direct REST writes and RPC/service-role writers.
-- Count rows, not statements: bulk writes and reorders must not bypass the cap.
-- 600 row mutations per minute leaves room for 16-row board reorders.
create table public.user_write_budgets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  writes integer not null check (writes between 1 and 600)
);
alter table public.user_write_budgets enable row level security;
alter table public.user_write_budgets force row level security;
revoke all on public.user_write_budgets from public, anon, authenticated;

create function public.enforce_user_write_budget() returns trigger
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
    -- Existing database exception code and worker rate-limit message.
    raise exception using errcode = 'P0001', message = 'rate_limited';
  end if;
  return null;
end;
$$;
revoke all on function public.enforce_user_write_budget() from public, anon, authenticated;

-- AFTER counts an upsert once and only charges rows that passed RLS/constraints.
-- These run before notification AFTER triggers; rejection rolls back the entire
-- statement (including counters and transactional pg_net queue entries).
create trigger aaa_enforce_write_budget after insert or update or delete on public.reminders
  for each row execute function public.enforce_user_write_budget();
create trigger aaa_enforce_write_budget after insert or update or delete on public.routine_reminders
  for each row execute function public.enforce_user_write_budget();
create trigger aaa_enforce_write_budget after insert or update or delete on public.device_tokens
  for each row execute function public.enforce_user_write_budget();
create trigger aaa_enforce_write_budget after insert or update or delete on public.lock_screen_prefs
  for each row execute function public.enforce_user_write_budget();
create trigger aaa_enforce_write_budget after insert or update or delete on public.agent_tokens
  for each row execute function public.enforce_user_write_budget();

commit;
