-- Run after migrations on a disposable database; fixtures roll back.
begin;

-- 1,000 owners with 10 routines each, including paused routines in both queries.
insert into auth.users(id)
select md5('routine-owner-plan-' || n)::uuid from generate_series(1, 1000) n;
insert into public.routine_reminders
  (user_id, text, interval_days, start_date, local_time, timezone, enabled, created_at)
select md5('routine-owner-plan-' || owner)::uuid, 'Plan fixture ' || routine,
  1, date '2026-10-25', time '19:00', 'UTC', routine % 2 = 0,
  timestamptz '2026-10-25 00:00Z' + routine * interval '1 second'
from generate_series(1, 1000) owner cross join generate_series(1, 10) routine;
analyze public.routine_reminders;

-- Match the web projection, owner predicate, ordering and authenticated RLS.
set local role authenticated;
select set_config('request.jwt.claim.sub', md5('routine-owner-plan-500')::uuid::text, true);
do $$
declare plan json;
begin
  execute $query$explain (analyze, buffers, format json)
    select id, text, interval_days, start_date, local_time, timezone, enabled, next_run_at
    from public.routine_reminders
    where user_id = md5('routine-owner-plan-500')::uuid order by created_at
  $query$ into plan;
  raise notice 'Owner loading plan: %', plan;
  assert plan::text like '%routine_reminders_user_created_idx%', 'Loading must use the owner index';
  assert plan::text not like '%Seq Scan%', 'Loading must not scan all owners';
  assert (plan->0->'Plan'->>'Actual Rows')::integer = 10, 'Loading must include paused routines';
end $$;
reset role;

-- The security-definer quota trigger counts all routines for one owner.
do $$
declare plan json;
begin
  execute $query$explain (analyze, buffers, format json)
    select count(*) from public.routine_reminders
    where user_id = md5('routine-owner-plan-500')::uuid
  $query$ into plan;
  raise notice 'Quota count plan: %', plan;
  assert plan::text like '%routine_reminders_user_created_idx%', 'Quota count must use the owner index';
  assert plan::text not like '%Seq Scan%', 'Quota count must not scan all owners';
  assert (select count(*) from public.routine_reminders
    where user_id = md5('routine-owner-plan-500')::uuid) = 10;
end $$;
rollback;
