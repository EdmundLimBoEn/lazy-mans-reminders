begin;

create function public.enforce_reminder_quota() returns trigger
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
      message = 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_reminder_quota() from public, anon, authenticated;
create trigger reminders_enforce_quota
  before insert or update of is_done, user_id on public.reminders
  for each row execute function public.enforce_reminder_quota();

create function public.enforce_routine_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  if (select count(*) from public.routine_reminders where user_id = new.user_id) >= 50 then
    raise exception using errcode = 'P0001',
      message = 'You can have at most 50 routines. Delete a routine before adding another.';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_routine_quota() from public, anon, authenticated;
create trigger routines_enforce_quota
  before insert on public.routine_reminders
  for each row execute function public.enforce_routine_quota();

create or replace function public.notify_reminder_push() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- set_updated_at runs even for no-op updates. Ignore that timestamp while
  -- retaining board order, completion, and routine firing changes.
  if tg_op = 'UPDATE' then
    if row(old.id, old.user_id, old.text, old.sort_order, old.is_done,
           old.created_at, old.completed_at, old.routine_id, old.routine_fired_at)
      is not distinct from
       row(new.id, new.user_id, new.text, new.sort_order, new.is_done,
           new.created_at, new.completed_at, new.routine_id, new.routine_fired_at) then
      return null;
    end if;
  end if;
  perform public.request_reminder_push(jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', case when TG_OP = 'DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end,
    'old_record', case when TG_OP = 'INSERT' then null else to_jsonb(OLD) end
  ));
  return null;
end;
$$;
revoke all on function public.notify_reminder_push() from public, anon, authenticated;

commit;
