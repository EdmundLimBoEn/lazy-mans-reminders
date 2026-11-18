-- Disposable database only. Capture submissions before pg_net can queue any HTTP.
begin;
create temporary table push_requests (destination text, headers jsonb, body jsonb);
create or replace function net.http_post(
  url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type":"application/json"}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint language plpgsql as $$
begin
  insert into pg_temp.push_requests values (url, headers, body);
  return 1;
end;
$$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('c', 64);
  job_id uuid;
  url_id uuid;
  secret_id uuid;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values (device, owner_id);
  insert into public.reminder_push_jobs(user_id, device_token, payload)
    values (owner_id, device, '{}'::jsonb) returning id into job_id;
  secret_id := vault.create_secret('fixture-a', 'lmr_webhook_secret');

  perform public.dispatch_reminder_push_jobs();
  assert not exists (select from pg_temp.push_requests),
    'A missing deployment URL must prevent submission';

  url_id := vault.create_secret('http://first.invalid', 'lmr_project_url');
  update public.reminder_push_jobs set next_attempt_at = now() where id = job_id;
  perform public.dispatch_reminder_push_jobs();
  assert not exists (select from pg_temp.push_requests),
    'An insecure deployment URL must prevent submission';

  perform vault.update_secret(url_id, 'https://first.invalid/');
  update public.reminder_push_jobs set next_attempt_at = now() where id = job_id;
  perform public.dispatch_reminder_push_jobs();

  perform vault.update_secret(url_id, 'https://second.invalid');
  perform vault.update_secret(secret_id, 'fixture-b');
  update public.reminder_push_jobs set next_attempt_at = now() where id = job_id;
  perform public.dispatch_reminder_push_jobs();

  assert (select count(*) = 2 from pg_temp.push_requests);
  assert exists (select from pg_temp.push_requests
    where destination = 'https://first.invalid/functions/v1/send-reminder-push'
      and headers->>'x-webhook-secret' = 'fixture-a' and body = jsonb_build_object('job_id', job_id));
  assert exists (select from pg_temp.push_requests
    where destination = 'https://second.invalid/functions/v1/send-reminder-push'
      and headers->>'x-webhook-secret' = 'fixture-b' and body = jsonb_build_object('job_id', job_id));
end;
$$;
rollback;
