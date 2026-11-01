-- Disposable database only; all fixture changes roll back.
begin;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111');
insert into public.reminders(id, user_id, text, is_done) values
  ('11111111-1111-4111-8111-111111111112', '11111111-1111-4111-8111-111111111111', 'Reopen fixture', true);
-- Fix the window to avoid rollover and leave exactly one mutation available.
update public.user_write_budgets set writes = 599,
  window_started_at = statement_timestamp() + interval '1 hour'
where user_id = '11111111-1111-4111-8111-111111111111';
set local role service_role;
do $$ declare r public.reminders; first_updated_at timestamptz; begin
  select * into strict r from public.reopen_reminder(
    '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111112');
  assert not r.is_done and r.completed_at is null;
  first_updated_at := r.updated_at;
  for i in 1..3 loop
    select * into strict r from public.reopen_reminder(
      '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111112');
    assert not r.is_done and r.updated_at = first_updated_at;
  end loop;
  -- Supplying unchanged text must also avoid a write.
  select * into strict r from public.reopen_reminder(
    '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111112', 'Reopen fixture');
  assert r.text = 'Reopen fixture';
  begin
    perform public.reopen_reminder('11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111112', 'Edited fixture');
    raise exception 'Text edit bypassed exhausted budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  assert not exists (select 1 from public.reopen_reminder(
    '22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111112'));
end $$;
reset role;
do $$ begin
  assert (select writes = 600 from public.user_write_budgets
    where user_id = '11111111-1111-4111-8111-111111111111');
end $$;
update public.user_write_budgets set writes = 599
where user_id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ declare r public.reminders; begin
  select * into strict r from public.reopen_reminder(
    '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111112', 'Edited fixture');
  assert r.text = 'Edited fixture' and not r.is_done;
  select * into strict r from public.reopen_reminder(
    '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111112');
  assert r.text = 'Edited fixture';
end $$;
rollback;
