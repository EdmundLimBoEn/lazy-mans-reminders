-- Disposable database only, after the write-budget and reorder migrations.
-- Reconstruct legacy data that predates the raw-length constraint.
begin;
insert into auth.users(id) values ('55555555-5555-4555-8555-555555555555');
alter table public.reminders drop constraint reminders_text_raw_length;
alter table public.reminders disable trigger user;
insert into public.reminders(user_id, text, sort_order, is_done, updated_at)
select '55555555-5555-4555-8555-555555555555',
  repeat(' ', 1000) || repeat('é', 500) || repeat(' ', 1000), n, n > 2,
  '2026-01-01'::timestamptz
from generate_series(1, 603) n;
insert into public.reminders(user_id, text, sort_order, updated_at) values
  ('55555555-5555-4555-8555-555555555555', '  keep padding  ', 0, '2026-01-01');
alter table public.reminders enable trigger user;
alter table public.reminders add constraint reminders_text_raw_length
  check (char_length(text) <= 1000) not valid;
commit;

\ir ../migrations/202610280002_normalize_legacy_reminder_text.sql

begin;
do $$
begin
  assert (select convalidated from pg_constraint
    where conrelid = 'public.reminders'::regclass and conname = 'reminders_text_raw_length');
  assert (select count(*) = 603 from public.reminders
    where user_id = '55555555-5555-4555-8555-555555555555' and text = repeat('é', 500)),
    'Normalize both active and completed rows without truncating meaningful text';
  assert exists (select 1 from public.reminders
    where user_id = '55555555-5555-4555-8555-555555555555' and text = '  keep padding  '),
    'Already valid text must remain unchanged';
  assert not exists (select 1 from public.reminders
    where user_id = '55555555-5555-4555-8555-555555555555' and updated_at <> '2026-01-01'::timestamptz),
    'Normalization must preserve edit timestamps';
  assert not exists (select 1 from public.user_write_budgets
    where user_id = '55555555-5555-4555-8555-555555555555'),
    'Bulk normalization must not consume the owner write budget';
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-4555-8555-555555555555';
do $$
declare ordered_ids uuid[];
begin
  select array_agg(id order by sort_order desc) into ordered_ids
    from public.reminders where not is_done;
  perform public.reorder_reminders(ordered_ids);
  assert (select sort_order = 0 from public.reminders where id = ordered_ids[1]);
  update public.reminders set is_done = true where id = ordered_ids[1];
  assert (select is_done and completed_at is not null from public.reminders where id = ordered_ids[1]),
    'Legacy reminders must remain completable and completion triggers must be restored';
  begin
    update public.reminders set text = repeat(' ', 1000) || 'x' where id = ordered_ids[1];
    raise exception 'Oversized updates must still be rejected';
  exception when check_violation then null;
  end;
end $$;
reset role;
do $$ begin
  assert (select writes = 4 from public.user_write_budgets
    where user_id = '55555555-5555-4555-8555-555555555555'),
    'Write-budget trigger must be restored after normalization';
end $$;
delete from auth.users where id = '55555555-5555-4555-8555-555555555555';
commit;
