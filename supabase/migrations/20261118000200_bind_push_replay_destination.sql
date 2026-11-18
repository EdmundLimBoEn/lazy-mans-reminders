begin;

-- Before applying, set lmr_project_url in this deployment's Vault to its
-- HTTPS project origin, alongside lmr_webhook_secret.
create or replace function public.post_reminder_push(payload jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  webhook_secret text;
begin
  select max(decrypted_secret) filter (where name = 'lmr_project_url'),
         max(decrypted_secret) filter (where name = 'lmr_webhook_secret')
    into project_url, webhook_secret
    from vault.decrypted_secrets
    where name in ('lmr_project_url', 'lmr_webhook_secret');

  if project_url is null or project_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$' then
    raise exception 'lmr_project_url missing or invalid in vault';
  end if;
  if webhook_secret is null or length(webhook_secret) = 0 then
    raise exception 'lmr_webhook_secret missing from vault';
  end if;

  return net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/send-reminder-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := payload,
    timeout_milliseconds := 60000
  );
end;
$$;

commit;
