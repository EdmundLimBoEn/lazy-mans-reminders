-- Run after migrations against a disposable database. All fixtures roll back.
begin;
-- Never send notifications from fixtures, including during compaction.
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

do $$
declare
  owner_id uuid := '11111111-1111-4111-8111-111111111111';
  other_id uuid := '22222222-2222-4222-8222-222222222222';
  result record;
  expected_ids uuid[];
begin
  insert into public.reminders(user_id, text, sort_order, is_done)
  values (owner_id, 'Completed maximum', 2147483647, true),
         (other_id, 'Other owner maximum', 2147483647, false);

  -- Completed-only boards start at zero, even with a maximum-order history row.
  select * into strict result from public.add_agent_reminder(owner_id, 'First');
  assert result.sort_order = 0 and result.active_count = 1 and result.capacity_maximum = 6;
  assert result.user_id = owner_id and result.text = 'First' and not result.is_done;

  update public.reminders set sort_order = 12 where id = result.id;
  select * into strict result from public.add_agent_reminder(owner_id, 'Second');
  assert result.sort_order = 13, 'Completed maximum must not affect an active append';
  assert (select sort_order = 12 from public.reminders where text = 'First'),
    'Ordinary appends must not compact the board';

  -- The last available integer is usable without premature compaction.
  update public.reminders set sort_order = 2147483646 where id = result.id;
  select * into strict result from public.add_agent_reminder(owner_id, 'Last integer');
  assert result.sort_order = 2147483647;
  assert (select sort_order = 2147483646 from public.reminders where text = 'Second');

  -- Exercise negative orders and ties resolved by created_at, then id.
  update public.reminders set sort_order = -20 where text = 'First';
  insert into public.reminders(id, user_id, text, sort_order, created_at) values
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', owner_id, 'Tie later id', 2147483647, '2020-01-01'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', owner_id, 'Tie earlier id', 2147483647, '2020-01-01');
  select array_agg(id order by sort_order, created_at, id) into expected_ids
  from public.reminders where user_id = owner_id and not is_done;

  select * into strict result from public.add_agent_reminder(owner_id, 'After recovery');
  assert result.sort_order = 5 and result.active_count = 6;
  assert (select array_agg(id order by sort_order, created_at, id) = expected_ids || result.id
    from public.reminders where user_id = owner_id and not is_done), 'Compaction changed board order';
  assert (select array_agg(sort_order order by sort_order) = array[0,1,2,3,4,5]
    from public.reminders where user_id = owner_id and not is_done), 'Compaction must reclaim headroom';
  assert (select sort_order = 2147483647 and is_done from public.reminders where text = 'Completed maximum');
  assert (select sort_order = 2147483647 from public.reminders where user_id = other_id),
    'Recovery must not modify another owner';

  -- Capacity rejection still precedes compaction and leaves the board untouched.
  update public.reminders set sort_order = 2147483647 where id = result.id;
  begin
    perform public.add_agent_reminder(owner_id, 'Over capacity');
    raise exception 'Full board accepted an agent addition';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'LMR_CAPACITY_REACHED' then raise; end if;
  end;
  assert (select sort_order = 2147483647 from public.reminders where id = result.id);
  -- Completing the maximum row restores additions without renumbering it.
  update public.reminders set is_done = true where id = result.id;
  select * into strict result from public.add_agent_reminder(owner_id, 'After completion');
  assert result.sort_order = 5 and result.active_count = 6;
end;
$$;

-- Replacing the function must preserve its service-role-only execution boundary.
do $$ begin
  assert not has_function_privilege('anon', 'public.add_agent_reminder(uuid,text)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.add_agent_reminder(uuid,text)', 'EXECUTE');
  assert has_function_privilege('service_role', 'public.add_agent_reminder(uuid,text)', 'EXECUTE');
end $$;
rollback;
