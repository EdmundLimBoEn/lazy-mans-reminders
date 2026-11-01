-- Disposable database only; all fixtures and transport replacement roll back.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'simulated transport outage';
end;
$$;
do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('c', 64);
  event jsonb;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values (device, owner_id);
  insert into public.reminder_push_jobs(user_id, device_token, payload, status, created_at)
    select owner_id, device, '{}'::jsonb,
      case when n % 3 = 0 then 'pending' when n % 3 = 1 then 'complete' else 'exhausted' end,
      now() - interval '8 days'
    from generate_series(1, 1001) n;
  event := jsonb_build_object('type', 'INSERT', 'record',
    jsonb_build_object('user_id', owner_id));
  perform public.request_reminder_push(event);
  assert (select count(*) = 1001 from public.reminder_push_jobs
    where user_id = owner_id and created_at < now() - interval '7 days'),
    'Push request performed global retention cleanup';
  perform public.dispatch_reminder_push_jobs();
  assert (select count(*) = 1001 from public.reminder_push_jobs
    where user_id = owner_id and created_at < now() - interval '7 days'),
    'Replay dispatch performed retention cleanup';

  -- Include the exact boundary and a recent job for every status.
  insert into public.reminder_push_jobs(user_id, device_token, payload, status, created_at)
    select owner_id, device, '{}'::jsonb, s, t
    from unnest(array['pending', 'complete', 'exhausted']) s
    cross join unnest(array[now() - interval '7 days', now()]) t;
  assert public.cleanup_reminder_push_jobs() = 1000, 'Cleanup did not bound its batch';
  assert (select count(*) = 1 from public.reminder_push_jobs
    where user_id = owner_id and created_at < now() - interval '7 days'),
    'Cleanup did not preserve remaining backlog';
  assert public.cleanup_reminder_push_jobs() = 1, 'Cleanup did not drain remaining backlog';
  assert public.cleanup_reminder_push_jobs() = 0, 'Cleanup deleted unexpired jobs';
  assert (select count(*) = 7 from public.reminder_push_jobs where user_id = owner_id),
    'Cleanup changed the seven-day retention boundary';
  assert not has_function_privilege('anon', 'public.cleanup_reminder_push_jobs()', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.cleanup_reminder_push_jobs()', 'EXECUTE');
  assert has_function_privilege('service_role', 'public.cleanup_reminder_push_jobs()', 'EXECUTE');
  assert exists (select 1 from cron.job where jobname = 'reminder-push-retention'
    and schedule = '* * * * *' and command = 'select public.cleanup_reminder_push_jobs();' and active),
    'Retention cleanup is not scheduled';
end;
$$;
rollback;
