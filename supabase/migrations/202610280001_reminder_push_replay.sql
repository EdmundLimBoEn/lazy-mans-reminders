begin;

-- One durable job per event/device, committed with the reminder mutation.
create table public.reminder_push_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_token text not null references public.device_tokens(token) on delete cascade,
  payload jsonb not null,
  outcomes jsonb not null default '{}'::jsonb,
  alert_sent boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'complete', 'exhausted')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.reminder_push_jobs enable row level security;
alter table public.reminder_push_jobs force row level security;
revoke all on public.reminder_push_jobs from public, anon, authenticated;
grant all on public.reminder_push_jobs to service_role;
create index reminder_push_jobs_due on public.reminder_push_jobs(next_attempt_at)
  where status = 'pending';
create index reminder_push_jobs_user on public.reminder_push_jobs(user_id);
create index reminder_push_jobs_device on public.reminder_push_jobs(device_token);

-- Keep the existing Vault-backed, fixed-destination transport private.
create or replace function public.post_reminder_push(payload jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  webhook_secret text;
  request_id bigint;
begin
  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'lmr_webhook_secret'
  limit 1;

  if webhook_secret is null or length(webhook_secret) = 0 then
    raise exception 'lmr_webhook_secret missing from vault';
  end if;

  select net.http_post(
    url := 'https://biwmsxbqrevtjwgsvsmu.supabase.co/functions/v1/send-reminder-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := payload,
    timeout_milliseconds := 60000
  ) into request_id;
  return request_id;
end;
$$;
revoke all on function public.post_reminder_push(jsonb) from public, anon, authenticated;

create function public.dispatch_reminder_push_jobs() returns void
language plpgsql security definer set search_path = '' as $$
declare
  job public.reminder_push_jobs%rowtype;
begin
  -- Also recovers HTTP timeouts, lost responses and crashed Edge workers.
  for job in select * from public.reminder_push_jobs
    where status = 'pending' and next_attempt_at <= clock_timestamp()
    order by next_attempt_at limit 100 for update skip locked
  loop
    if job.attempts >= 12 or job.created_at < now() - interval '24 hours'
      or not exists (select 1 from public.device_tokens
        where token = job.device_token and user_id = job.user_id) then
      update public.reminder_push_jobs set status = 'exhausted' where id = job.id;
      continue;
    end if;
    -- At least two minutes exceeds the device delivery slot. Cap at one hour.
    update public.reminder_push_jobs set attempts = attempts + 1,
      next_attempt_at = clock_timestamp() + make_interval(secs =>
        least(3600, 120 * power(2, job.attempts)::integer))
      where id = job.id;
    begin
      perform public.post_reminder_push(jsonb_build_object('job_id', job.id));
    exception when others then
      -- Never discard the durable job when submission itself fails.
      null;
    end;
  end loop;
  delete from public.reminder_push_jobs where created_at < now() - interval '7 days';
end;
$$;
revoke all on function public.dispatch_reminder_push_jobs() from public, anon, authenticated;
grant execute on function public.dispatch_reminder_push_jobs() to service_role;

create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.reminder_push_jobs(user_id, device_token, payload)
    select d.user_id, d.token, payload from public.device_tokens d
    where case when payload->>'type' = 'live_activity_refresh' then
      d.push_to_start_token is not null or d.activity_push_token is not null
        or d.retiring_activity_push_token is not null
    else d.user_id = (payload->'record'->>'user_id')::uuid end;
  perform public.dispatch_reminder_push_jobs();
  -- Existing callers discard the transport request ID; jobs own retry state now.
  return null;
end;
$$;
revoke all on function public.request_reminder_push(jsonb) from public, anon, authenticated;

select cron.schedule('reminder-push-replay', '* * * * *',
  $job$select public.dispatch_reminder_push_jobs();$job$);
commit;
