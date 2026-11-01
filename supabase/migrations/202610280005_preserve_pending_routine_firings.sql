create or replace function public.prepare_routine_schedule() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.text := trim(new.text);
  -- Clients may resubmit unchanged schedule columns when correcting text.
  -- Keep pending occurrences, including overdue ones, until the scheduler fires.
  if tg_op = 'INSERT' then
    new.next_run_at := public.next_routine_run(new.start_date, new.local_time, new.timezone, new.interval_days, now());
  elsif row(new.start_date, new.local_time, new.timezone, new.interval_days, new.enabled)
    is distinct from row(old.start_date, old.local_time, old.timezone, old.interval_days, old.enabled) then
    new.next_run_at := public.next_routine_run(new.start_date, new.local_time, new.timezone, new.interval_days, now());
  else
    new.next_run_at := old.next_run_at;
  end if;
  return new;
end;
$$;
