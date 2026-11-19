-- Run after migrations in a disposable database. Keep transport local.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  other_owner uuid := gen_random_uuid();
  device text := repeat('a', 64);
  job public.reminder_push_jobs%rowtype;
begin
  insert into auth.users(id) values (owner_id), (other_owner);
  insert into public.reminders(user_id, text, is_done, completed_at)
    values (owner_id, 'Expired push text fixture', true, now() - interval '4 days');
  insert into public.device_tokens(user_id, token)
    values (owner_id, device), (other_owner, repeat('b', 64));

  assert public.delete_old_completed_reminders() = 1;
  select * into strict job from public.reminder_push_jobs
    where user_id in (owner_id, other_owner);
  assert job.user_id = owner_id and job.device_token = device, 'DELETE push routed to wrong device';
  assert job.payload = jsonb_build_object(
    'type', 'DELETE', 'table', 'reminders', 'schema', 'public',
    'record', jsonb_build_object('user_id', owner_id)
  ), 'DELETE push must keep only the owner ID and event metadata';
end $$;
rollback;
