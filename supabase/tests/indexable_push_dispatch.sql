-- Disposable database only; fixtures and the transport replacement roll back.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('e', 64);
  candidate_query text;
  query_plan jsonb;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values (device, owner_id);
  insert into public.reminder_push_jobs(user_id, device_token, payload, next_attempt_at)
    select owner_id, device, '{}'::jsonb, clock_timestamp() + interval '1 day'
    from generate_series(1, 10000);
  insert into public.reminder_push_jobs(user_id, device_token, payload, next_attempt_at)
    select owner_id, device, '{}'::jsonb, clock_timestamp() - interval '1 minute'
    from generate_series(1, 101);
  analyze public.reminder_push_jobs;

  -- Explain the installed dispatcher's candidate query, not a duplicate query.
  -- Pass the captured cutoff as a parameter, as PL/pgSQL does for its variable.
  candidate_query := substring(pg_get_functiondef(
    'public.dispatch_reminder_push_jobs()'::regprocedure)
    from 'for job in (select[\s\S]*?)\s+loop');
  assert candidate_query is not null, 'Could not locate the dispatch candidate query';
  candidate_query := replace(candidate_query, 'dispatch_cutoff', '$1');
  execute 'explain (analyze, format json) ' || candidate_query
    into query_plan using clock_timestamp();
  assert jsonb_path_exists(query_plan,
    '$.** ? (@."Index Name" == "reminder_push_jobs_due" && exists(@."Index Cond"))'),
    'Dispatch must bound the pending index scan by next_attempt_at';

  perform public.dispatch_reminder_push_jobs();
  assert (select count(*) = 100 from public.reminder_push_jobs
    where user_id = owner_id and attempts = 1), 'Dispatch batch must remain capped at 100';
  perform public.dispatch_reminder_push_jobs();
  assert (select count(*) = 101 from public.reminder_push_jobs
    where user_id = owner_id and attempts = 1), 'Dispatch must drain remaining due jobs';
  assert (select count(*) = 10000 from public.reminder_push_jobs
    where user_id = owner_id and attempts = 0), 'Dispatch must leave future retries untouched';
end;
$$;
rollback;
