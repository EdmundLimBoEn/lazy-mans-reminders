begin;

create or replace function public.delete_old_completed_reminders()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_id uuid;
  reminder_id uuid;
  affected integer;
  deleted_count integer := 0;
begin
  for owner_id in
    select distinct user_id from public.reminders
    where is_done and completed_at < now() - interval '3 days'
    order by user_id
  loop
    -- Routines visit owners in due-time order and retain their budget locks.
    -- Skip busy owners before locking any reminders or charging deletes.
    if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 0)) then
      continue;
    end if;
    for reminder_id in
      select id from public.reminders
      where user_id = owner_id and is_done
        and completed_at < now() - interval '3 days'
      order by completed_at, id
      limit 600
      for update skip locked
    loop
      begin
        delete from public.reminders
        where id = reminder_id and user_id = owner_id and is_done
          and completed_at < now() - interval '3 days';
        get diagnostics affected = row_count;
        deleted_count := deleted_count + affected;
      exception when sqlstate 'P0001' then
        if sqlerrm <> 'rate_limited' then raise; end if;
        -- Another owner can still have capacity during service-role cleanup.
        exit;
      end;
    end loop;
  end loop;
  return deleted_count;
end;
$$;

commit;
