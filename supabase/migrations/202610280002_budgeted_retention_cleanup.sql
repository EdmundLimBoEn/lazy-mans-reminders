begin;

-- Keep invoker/RLS semantics, including service-role cleanup across owners.
-- Each successful row consumes the existing shared budget. A rejected row rolls
-- back alone, preserving progress and leaving the remainder for a later window.
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
    where is_done and completed_at < now() - interval '7 days'
    order by user_id
  loop
    for reminder_id in
      select id from public.reminders
      where user_id = owner_id and is_done
        and completed_at < now() - interval '7 days'
      order by completed_at, id
      limit 600
    loop
      begin
        delete from public.reminders
        where id = reminder_id and user_id = owner_id and is_done
          and completed_at < now() - interval '7 days';
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

revoke all on function public.delete_old_completed_reminders() from public;
grant execute on function public.delete_old_completed_reminders() to authenticated, service_role;

commit;
