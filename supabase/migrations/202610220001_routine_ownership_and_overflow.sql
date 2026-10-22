begin;

-- Prevent writes between repairing existing data and enforcing the constraints.
lock table public.routine_reminders, public.reminders in access exclusive mode;
update public.reminders as reminder
set routine_id = null, routine_fired_at = null
from public.routine_reminders as routine
where reminder.routine_id = routine.id and reminder.user_id <> routine.user_id;

alter table public.routine_reminders add constraint routine_reminders_id_user_key unique (id, user_id);
alter table public.reminders drop constraint reminders_routine_id_fkey;
alter table public.reminders add constraint reminders_routine_id_fkey
  foreign key (routine_id, user_id) references public.routine_reminders(id, user_id)
  on delete set null (routine_id);

-- Reserve the integer minimum as headroom, including for existing boards.
update public.reminders set sort_order = -2147483647 where sort_order = '-2147483648'::integer;
alter table public.reminders add constraint reminders_sort_order_range
  check (sort_order >= -2147483647);

create or replace function public.fire_due_routines() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  routine public.routine_reminders%rowtype;
  fired integer := 0;
  run_time timestamptz := now();
begin
  for routine in select * from public.routine_reminders
    where enabled and next_run_at <= run_time order by next_run_at for update skip locked
  loop
    begin
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(routine.user_id::text, 0));
      insert into public.reminders(user_id, text, sort_order, routine_id, routine_fired_at)
      values (routine.user_id, routine.text,
        (select greatest(coalesce(min(sort_order)::bigint, 1) - 1, -2147483647)::integer
          from public.reminders where user_id = routine.user_id),
        routine.id, routine.next_run_at)
      on conflict (routine_id) where routine_id is not null do update
        set text = excluded.text, sort_order = excluded.sort_order, is_done = false, routine_fired_at = excluded.routine_fired_at
        where public.reminders.user_id = excluded.user_id;
      if not found then
        continue;
      end if;
      update public.routine_reminders set next_run_at = public.next_routine_run(
        routine.start_date, routine.local_time, routine.timezone, routine.interval_days, run_time)
        where id = routine.id;
      fired := fired + 1;
    exception when others then
      -- The subtransaction rolls back this routine only; leave it due for retry.
      raise warning 'Routine % failed (SQLSTATE %)', routine.id, sqlstate;
    end;
  end loop;
  return fired;
end;
$$;

commit;
