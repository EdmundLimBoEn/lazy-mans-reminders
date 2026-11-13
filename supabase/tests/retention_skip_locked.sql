-- Disposable database only. Committed fixtures let two real sessions share rows.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('retention_writer', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));

begin;
-- Keep fixture setup silent even if notification triggers are installed.
alter table public.reminders disable trigger user;
insert into auth.users(id) values ('55555555-5555-4555-8555-555555555555');
insert into public.reminders(id, user_id, text, is_done, completed_at) values
 ('55555555-5555-4555-8555-555555555551', '55555555-5555-4555-8555-555555555555', 'Locked expired', true, now() - interval '5 days'),
 ('55555555-5555-4555-8555-555555555552', '55555555-5555-4555-8555-555555555555', 'Available expired', true, now() - interval '4 days');
alter table public.reminders enable trigger user;
insert into public.user_write_budgets(user_id, window_started_at, writes)
values ('55555555-5555-4555-8555-555555555555', statement_timestamp() + interval '1 hour', 598);
commit;

select extensions.dblink_exec('retention_writer', 'begin');
select * from extensions.dblink('retention_writer',
  'select id from public.reminders where id = ''55555555-5555-4555-8555-555555555551'' for update') as locked(id uuid);

begin;
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;
set local lock_timeout = '500ms';
set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-4555-8555-555555555555';
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'Cleanup must skip the locked row and delete the available row';
  assert exists (select 1 from public.reminders where id = '55555555-5555-4555-8555-555555555551');
  assert not exists (select 1 from public.reminders where id = '55555555-5555-4555-8555-555555555552');
  assert public.delete_old_completed_reminders() = 0, 'A fully locked backlog must return without waiting';
end $$;
reset role;
select extensions.dblink_exec('retention_writer', 'rollback');
set local role authenticated;
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'Skipped rows must remain eligible after the writer releases its lock';
  assert public.delete_old_completed_reminders() = 0;
end $$;
reset role;
do $$ begin
  assert (select writes = 600 from public.user_write_budgets
    where user_id = '55555555-5555-4555-8555-555555555555'), 'Only deleted rows consume budget';
end $$;
-- Restore the notification function and the fixtures before removing them.
rollback;
select extensions.dblink_disconnect('retention_writer');
begin;
alter table public.reminders disable trigger user;
delete from auth.users where id = '55555555-5555-4555-8555-555555555555';
alter table public.reminders enable trigger user;
commit;
