-- Bound stored text, including whitespace, while retaining the existing 500-character
-- trimmed limit. 1000 allows modest padding without permitting unbounded payloads;
-- this storage ceiling does not change the push API's stricter 500-character limit.
-- NOT VALID enforces new writes without rejecting legacy oversized rows.
alter table public.reminders
  add constraint reminders_text_raw_length check (char_length(text) <= 1000) not valid;

do $$
begin
  if not exists (select 1 from public.reminders where char_length(text) > 1000) then
    alter table public.reminders validate constraint reminders_text_raw_length;
  end if;
end;
$$;

-- CREATE OR REPLACE retains existing grants, including the anon/PUBLIC revocations.
create or replace function public.mint_agent_token(p_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  trimmed_name text := trim(p_name);
  active_count integer;
  secret text;
  new_id uuid;
  hash text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(trimmed_name) < 1 or char_length(trimmed_name) > 64 then
    raise exception 'Invalid token name';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));

  select count(*) into active_count
  from public.agent_tokens
  where user_id = uid and revoked_at is null;

  if active_count >= 20 then
    raise exception 'Token limit reached';
  end if;

  secret := replace(
    replace(rtrim(encode(extensions.gen_random_bytes(24), 'base64'), '='), '+', '-'),
    '/',
    '_'
  );
  new_id := pg_catalog.gen_random_uuid();
  hash := encode(extensions.digest(convert_to(secret, 'UTF8'), 'sha256'), 'hex');

  insert into public.agent_tokens (id, user_id, name, token_hash)
  values (new_id, uid, trimmed_name, hash);

  return 'lmr_' || new_id::text || '_' || secret;
end;
$$;

