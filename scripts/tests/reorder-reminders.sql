-- Run only in an isolated PostgreSQL test database.
\set ON_ERROR_STOP on
begin;
create role anon;
create role authenticated;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to authenticated;
create publication supabase_realtime;
\ir ../../supabase/migrations/202608060001_create_reminders.sql
\ir ../../supabase/migrations/20261010040000_reorder_reminders.sql
grant select, insert, update, delete on public.reminders to authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
insert into public.reminders (id, user_id, text, sort_order, is_done) values
 ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'First', 0, false),
 ('00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000001', 'Second', 0, false),
 ('00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000001', 'Third', 9, false),
 ('00000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000001', 'Done', 7, true),
 ('00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000002', 'Other user', 4, false);
do $$ begin
  assert not has_function_privilege('anon', 'public.reorder_reminders(uuid[])', 'execute');
  assert has_function_privilege('authenticated', 'public.reorder_reminders(uuid[])', 'execute');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
do $$
declare
  ordered uuid[] := array['00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000012']::uuid[];
  bad uuid[];
  returned uuid[];
begin
  select array_agg(id order by sort_order) into returned from public.reorder_reminders(ordered);
  assert returned = ordered, 'Multi-position drag must persist requested order';
  assert (select array_agg(sort_order order by sort_order) from public.reminders where not is_done) = array[0,1,2];
  assert (select sort_order from public.reminders where is_done) = 7, 'Done notes must stay untouched';
  foreach bad slice 1 in array array[
    array[ordered[1], ordered[1], ordered[3]],
    array[ordered[1], ordered[2], '00000000-0000-0000-0000-000000000021'::uuid],
    array[ordered[1], ordered[2], '00000000-0000-0000-0000-000000000014'::uuid],
    array[ordered[1], ordered[2], '00000000-0000-0000-0000-000000000099'::uuid]
  ] loop
    begin
      perform public.reorder_reminders(bad);
      raise exception 'Expected rejection';
    exception when raise_exception then
      if sqlerrm <> 'The board changed. Refresh and try reordering again.' then raise; end if;
    end;
  end loop;
  begin
    perform public.reorder_reminders(ordered[1:2]);
    raise exception 'Expected rejection';
  exception when raise_exception then
    if sqlerrm <> 'The board changed. Refresh and try reordering again.' then raise; end if;
  end;
  assert (select array_agg(id order by sort_order) from public.reminders where not is_done) = ordered,
    'Rejected stale, foreign, duplicate, done and missing IDs must not change the order';
end $$;
reset role;
do $$ begin
  assert (select sort_order from public.reminders where text = 'Other user') = 4, 'Other accounts must stay untouched';
end $$;
rollback;
