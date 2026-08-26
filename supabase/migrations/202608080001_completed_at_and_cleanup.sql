-- Track when a reminder was completed so stale done rows can be deleted after 7 days.
-- Clients call delete_old_completed_reminders() on board load; optional pg_cron can also schedule it.

alter table public.reminders
  add column completed_at timestamptz;

-- Best-effort backfill for rows already marked done.
update public.reminders
set completed_at = updated_at
where is_done = true
  and completed_at is null;

create index reminders_stale_completed_idx
  on public.reminders (completed_at)
  where is_done = true and completed_at is not null;

create or replace function public.set_completed_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.is_done and (tg_op = 'INSERT' or not old.is_done) then
    new.completed_at = coalesce(new.completed_at, now());
  elsif not new.is_done then
    new.completed_at = null;
  end if;
  return new;
end;
$$;

revoke all on function public.set_completed_at() from public;

create trigger reminders_set_completed_at
  before insert or update of is_done on public.reminders
  for each row execute function public.set_completed_at();

-- Deletes done reminders older than 7 days.
-- security invoker: authenticated callers only affect their own rows (RLS);
-- service_role (optional cron) bypasses RLS and cleans all users.
create or replace function public.delete_old_completed_reminders()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.reminders
  where is_done = true
    and completed_at is not null
    and completed_at < now() - interval '7 days';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.delete_old_completed_reminders() from public;
grant execute on function public.delete_old_completed_reminders() to authenticated;
grant execute on function public.delete_old_completed_reminders() to service_role;
