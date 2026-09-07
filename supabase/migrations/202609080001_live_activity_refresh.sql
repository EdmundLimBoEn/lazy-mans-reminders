create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create or replace function public.request_reminder_push(payload jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  webhook_secret text;
  request_id bigint;
begin
  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'lmr_webhook_secret'
  limit 1;

  if webhook_secret is null or length(webhook_secret) = 0 then
    raise exception 'lmr_webhook_secret missing from vault';
  end if;

  select net.http_post(
    url := 'https://biwmsxbqrevtjwgsvsmu.supabase.co/functions/v1/send-reminder-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := payload,
    timeout_milliseconds := 60000
  ) into request_id;
  return request_id;
end;
$$;

revoke all on function public.request_reminder_push(jsonb) from public, anon, authenticated;

create or replace function public.notify_reminder_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.request_reminder_push(jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', case when TG_OP = 'DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end
  ));
  return null;
end;
$$;

revoke all on function public.notify_reminder_push() from public, anon, authenticated;

drop trigger if exists send_reminder_push on public.reminders;
create trigger send_reminder_push
after insert or update or delete on public.reminders
for each row execute function public.notify_reminder_push();

create function public.track_live_activity_start()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if NEW.activity_push_token is not null then
    NEW.activity_started_at := coalesce(NEW.activity_started_at, now());
  end if;
  return NEW;
end;
$$;

create trigger device_tokens_track_live_activity_start
before insert or update of activity_push_token on public.device_tokens
for each row execute function public.track_live_activity_start();

select cron.schedule(
  'live-activity-refresh',
  '*/15 * * * *',
  $job$select public.request_reminder_push('{"type":"live_activity_refresh"}'::jsonb);$job$
);
