begin;

-- Capture wall time once so the pending-job index can bound the due range.
create or replace function public.dispatch_reminder_push_jobs() returns void
language plpgsql security definer set search_path = '' as $$
declare
  job public.reminder_push_jobs%rowtype;
  dispatch_cutoff timestamptz := clock_timestamp();
begin
  -- Also recovers HTTP timeouts, lost responses and crashed Edge workers.
  for job in select * from public.reminder_push_jobs
    where status = 'pending' and next_attempt_at <= dispatch_cutoff
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

commit;
