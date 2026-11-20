begin;

create function public.create_routine_reminder(
  p_id uuid, p_user_id uuid, p_text text, p_interval_days integer,
  p_start_date date, p_local_time time, p_timezone text
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  routine_id uuid;
begin
  if owner_id is null or p_user_id is distinct from owner_id then
    raise insufficient_privilege using
      message = 'new row violates row-level security policy for table "routine_reminders"';
  end if;

  -- Serialize with other creates using the same lock as the quota trigger.
  -- A retry at quota must return before attempting another insert.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 0));
  select id into routine_id from public.routine_reminders
    where id = p_id and user_id = owner_id;
  if found then
    return routine_id;
  end if;

  insert into public.routine_reminders (id, user_id, text, interval_days, start_date, local_time, timezone)
    values (p_id, owner_id, p_text, p_interval_days, p_start_date, p_local_time, p_timezone)
    returning id into routine_id;
  return routine_id;
end;
$$;

revoke all on function public.create_routine_reminder(uuid, uuid, text, integer, date, time, text) from public, anon, service_role;
grant execute on function public.create_routine_reminder(uuid, uuid, text, integer, date, time, text) to authenticated;

commit;
