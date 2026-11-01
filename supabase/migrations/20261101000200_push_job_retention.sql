begin;

-- Retention must not run synchronously with reminder writes or replay dispatch.
create index reminder_push_jobs_created_at on public.reminder_push_jobs(created_at);

create or replace function public.dispatch_reminder_push_jobs() returns void
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
end;
$$;
revoke all on function public.dispatch_reminder_push_jobs() from public, anon, authenticated;
grant execute on function public.dispatch_reminder_push_jobs() to service_role;

-- Preserve the existing seven-day policy, with bounded work per scheduled run.
create function public.cleanup_reminder_push_jobs() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  deleted_count integer;
begin
  delete from public.reminder_push_jobs
  where id in (
    select id from public.reminder_push_jobs
    where created_at < now() - interval '7 days'
    order by created_at
    limit 1000 for update skip locked
  );
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
revoke all on function public.cleanup_reminder_push_jobs() from public, anon, authenticated;
grant execute on function public.cleanup_reminder_push_jobs() to service_role;

select cron.schedule('reminder-push-retention', '* * * * *',
  $job$select public.cleanup_reminder_push_jobs();$job$);

commit;
