begin;

create or replace function public.enforce_reminder_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_done then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.user_id = old.user_id and not old.is_done then
      return new;
    end if;
  end if;

  -- Share the agent/scheduler lock so every writer counts after earlier writes commit.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  -- MAX_ACTIVE_REMINDERS in web/src/lib/reminders.ts; phone display limits may be lower.
  if (select count(*) from public.reminders where user_id = new.user_id and not is_done) >= 16 then
    -- BEFORE INSERT also runs for ON CONFLICT: refreshing an active routine or
    -- upserting an existing active ID does not consume another slot. The UPDATE
    -- trigger below still checks any subsequent activation/ownership change.
    if tg_op = 'INSERT' and exists (
      select 1 from public.reminders
      where user_id = new.user_id and not is_done
        and (id = new.id or routine_id = new.routine_id)
    ) then
      return new;
    end if;
    raise exception using errcode = 'P0001',
      message = 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.',
      detail = '16 LMR_CAPACITY_REACHED';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_reminder_quota() from public, anon, authenticated;

commit;
