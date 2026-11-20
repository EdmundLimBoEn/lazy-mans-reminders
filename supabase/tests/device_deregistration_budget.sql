-- Disposable database only. Run after the device deregistration budget migration.
begin;
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.device_tokens(token, user_id) values
  (repeat('a', 64), '11111111-1111-4111-8111-111111111111'),
  (repeat('b', 64), '22222222-2222-4222-8222-222222222222');
-- Pin the window so a minute rollover cannot replenish the owner's budget.
update public.user_write_budgets set writes = 600, window_started_at = now() + interval '1 hour'
where user_id = '11111111-1111-4111-8111-111111111111';

set local role service_role;
do $$ begin
  delete from public.device_tokens where token = repeat('a', 64);
  raise exception 'A background delete bypassed the owner budget';
exception when sqlstate 'P0001' then
  if sqlerrm <> 'rate_limited' then raise; end if;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
  delete from public.device_tokens where token = repeat('b', 64);
  assert not found, 'Device removal must enforce owner RLS';
  delete from public.device_tokens where user_id = auth.uid() and token = repeat('a', 64);
  assert found, 'Sign-out must remove the owner registration at the limit';
  begin
    insert into public.reminders(user_id, text) values (auth.uid(), 'Budget fixture');
    raise exception 'Deregistration replenished the content budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from public.device_tokens where token = repeat('a', 64));
  assert exists (select 1 from public.device_tokens where token = repeat('b', 64));
end $$;
rollback;
