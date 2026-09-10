begin;

do $$
begin
  if to_regprocedure('public.request_reminder_push(jsonb)') is null then
    raise exception 'Live Activity refresh is not installed';
  end if;
  if not exists (
    select 1 from cron.job
    where jobname = 'live-activity-refresh' and active and schedule = '*/15 * * * *'
  ) then
    raise exception 'Live Activity refresh is not scheduled every 15 minutes';
  end if;
  if has_function_privilege('anon', 'public.request_reminder_push(jsonb)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.request_reminder_push(jsonb)', 'EXECUTE') then
    raise exception 'Clients must not invoke the privileged push sender';
  end if;
end;
$$;

create temporary table activity_test_devices (
  activity_push_token text,
  activity_started_at timestamptz
);
create trigger track_activity
before insert or update of activity_push_token on activity_test_devices
for each row execute function public.track_live_activity_start();

insert into activity_test_devices values ('first', null);
do $$
begin
  if (select activity_started_at is null from activity_test_devices) then
    raise exception 'Locally started activity has no start time';
  end if;
end;
$$;

update activity_test_devices set activity_started_at = now() - interval '7 hours';
update activity_test_devices set activity_push_token = 'first';
do $$
begin
  if (select activity_started_at <> now() - interval '7 hours' from activity_test_devices) then
    raise exception 'Repeated token registration reset the activity age';
  end if;
end;
$$;

update activity_test_devices set activity_push_token = 'rotated';
do $$
begin
  if (select activity_started_at <> now() - interval '7 hours' from activity_test_devices) then
    raise exception 'Token rotation reset the age of the same activity';
  end if;
end;
$$;

create temporary table activity_test_reminders (id uuid, text text);
create trigger notify_activity
after insert or update or delete on activity_test_reminders
for each row execute function public.notify_reminder_push();

insert into activity_test_reminders values (gen_random_uuid(), 'throwaway lifecycle probe');
update activity_test_reminders set text = 'updated probe';
delete from activity_test_reminders;

do $$
declare
  events text[];
begin
  select array_agg(convert_from(body, 'UTF8')::jsonb ->> 'type' order by id)
  into events
  from net.http_request_queue
  where convert_from(body, 'UTF8')::jsonb ->> 'table' = 'activity_test_reminders';
  if events is distinct from array['INSERT', 'UPDATE', 'DELETE'] then
    raise exception 'Reminder webhook did not queue INSERT, UPDATE, DELETE';
  end if;
end;
$$;

-- pg_net only sends after commit. Roll back the probes so no notification leaves the database.
rollback;
select 'Live Activity scheduler, token age, permissions, and webhook tests passed' as result;
