-- Run after migrations in a disposable database. Fixtures roll back.
begin;
-- Suppress push delivery for fixture writes.
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select null::bigint $$;

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.reminders(user_id, text)
select auth.uid(), 'Active ' || n from generate_series(1, 15) n;
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
select auth.uid(), 'Routine ' || n, 1, current_date, '19:00', 'UTC' from generate_series(1, 49) n;

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
insert into public.reminders(user_id, text) values (auth.uid(), 'Own reminder');

do $$
declare
  owner_id constant uuid := '11111111-1111-4111-8111-111111111111';
  writer_id constant uuid := auth.uid();
  statement text;
  failures text[] := '{}';
begin
  for slots_left in reverse 1..0 loop
    foreach statement in array array[
      $sql$insert into public.reminders(user_id, text) values ($1, 'Cross-account reminder')$sql$,
      $sql$update public.reminders set user_id = $1 where text = 'Own reminder'$sql$,
      $sql$insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
           values ($1, 'Cross-account routine', 1, current_date, '19:00', 'UTC')$sql$
    ] loop
      begin
        execute statement using owner_id;
        raise exception 'Expected RLS rejection for %', statement;
      exception
        when insufficient_privilege then null;
        when raise_exception then
          failures := array_append(failures, format('%s slot(s) left: %s', slots_left, sqlerrm));
      end;
    end loop;

    if slots_left = 1 then
      perform set_config('request.jwt.claim.sub', owner_id::text, true);
      insert into public.reminders(user_id, text) values (auth.uid(), 'Last reminder');
      insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
      values (auth.uid(), 'Last routine', 1, current_date, '19:00', 'UTC');
      perform set_config('request.jwt.claim.sub', writer_id::text, true);
    end if;
  end loop;
  if cardinality(failures) > 0 then
    raise exception 'Expected RLS errors: %', array_to_string(failures, ' | ');
  end if;
end $$;
rollback;
