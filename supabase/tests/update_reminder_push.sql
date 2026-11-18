-- Run after migrations in a disposable database. Keep transport local.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('a', 64);
  reminder_id uuid;
  routine uuid;
  routine_reminder_id uuid;
  previous_firing timestamptz := now() - interval '1 day';
  next_firing timestamptz := now() - interval '1 minute';
  refresh_payload jsonb := jsonb_build_object(
    'type', 'UPDATE', 'table', 'reminders', 'schema', 'public',
    'record', jsonb_build_object('user_id', owner_id)
  );
  alert_payload jsonb;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.reminders(user_id, text) values (owner_id, 'Removed text')
    returning id into reminder_id;
  insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
    values (owner_id, 'Routine alert text', 1, current_date, '09:00', 'UTC')
    returning id into routine;
  insert into public.reminders(user_id, text, routine_id, routine_fired_at)
    values (owner_id, 'Previous routine text', routine, previous_firing)
    returning id into routine_reminder_id;
  insert into public.device_tokens(user_id, token) values (owner_id, device);

  update public.reminders set text = 'Edited text' where id = reminder_id;
  update public.reminders set text = 'Edited routine text' where id = routine_reminder_id;
  assert (select count(*) = 2 and bool_and(payload = refresh_payload)
    from public.reminder_push_jobs where user_id = owner_id and device_token = device),
    'Ordinary edits must queue owner-only refreshes';

  update public.routine_reminders set next_run_at = next_firing where id = routine;
  assert public.fire_due_routines() = 1, 'The routine must fire';
  select payload into strict alert_payload from public.reminder_push_jobs
    where user_id = owner_id and device_token = device and payload <> refresh_payload;
  assert alert_payload = jsonb_build_object(
    'type', 'UPDATE', 'table', 'reminders', 'schema', 'public',
    'record', jsonb_build_object('id', routine_reminder_id, 'user_id', owner_id,
      'text', 'Routine alert text', 'routine_id', routine, 'routine_fired_at', next_firing),
    'old_record', jsonb_build_object('routine_fired_at', previous_firing)
  ), 'Routine firing must queue only alert fields and the previous firing timestamp';
end $$;
rollback;
