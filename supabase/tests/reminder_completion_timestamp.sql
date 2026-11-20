begin;

create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111');
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

set local role service_role;
insert into public.reminders(user_id, text, is_done, completed_at)
values (auth.uid(), 'Expired', true, now() - interval '4 days');

set local role authenticated;
do $$
declare
  reminder_id uuid;
  stamped_at timestamptz;
begin
  insert into public.reminders(user_id, text) values (auth.uid(), 'Active')
    returning id into reminder_id;
  insert into public.reminders(user_id, text, is_done) values (auth.uid(), 'Done', true)
    returning completed_at into stamped_at;
  assert stamped_at = now(), 'Inserting a completed reminder must record the database time';

  begin
    insert into public.reminders(user_id, text, is_done, completed_at)
    values (auth.uid(), 'Supplied timestamp', true, now() + interval '1 day');
    raise exception 'Client supplied completed_at on insert';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.reminders set is_done = true, completed_at = now() + interval '1 day'
      where id = reminder_id;
    raise exception 'Client supplied completed_at on completion';
  exception when insufficient_privilege then null;
  end;

  update public.reminders set is_done = true where id = reminder_id
    returning completed_at into stamped_at;
  assert stamped_at = now(), 'Completing a reminder must record the database time';

  begin
    update public.reminders set completed_at = null where id = reminder_id;
    raise exception 'Client cleared completed_at';
  exception when insufficient_privilege then null;
  end;

  assert public.delete_old_completed_reminders() = 1;
  assert not exists (select 1 from public.reminders where text = 'Expired'),
    'Cleanup must delete the expired fixture';
  assert exists (select 1 from public.reminders where id = reminder_id and completed_at = now()),
    'Cleanup must retain the newly completed reminder';
  assert exists (select 1 from public.reopen_reminder(auth.uid(), reminder_id)
                 where not is_done and completed_at is null), 'Reopening must clear the timestamp';
end $$;

rollback;
