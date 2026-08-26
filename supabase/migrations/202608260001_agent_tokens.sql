create table public.agent_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 64),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz
);

create index agent_tokens_user_id_idx on public.agent_tokens (user_id);

alter table public.agent_tokens enable row level security;
alter table public.agent_tokens force row level security;

create policy "Users can read their agent tokens"
  on public.agent_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can delete their agent tokens"
  on public.agent_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create view public.agent_token_clients
with (security_invoker = true)
as
select id, user_id, name, created_at, last_used_at, revoked_at
from public.agent_tokens;

revoke all on public.agent_tokens from public, anon, authenticated;
grant select (id, user_id, name, created_at, last_used_at, revoked_at)
  on public.agent_tokens to authenticated;
grant delete on public.agent_tokens to authenticated;
grant select on public.agent_token_clients to authenticated;

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

create or replace function public.revoke_agent_token(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  updated integer;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  update public.agent_tokens
  set revoked_at = now()
  where id = p_id
    and user_id = uid
    and revoked_at is null;

  get diagnostics updated = row_count;
  return updated > 0;
end;
$$;

revoke all on function public.mint_agent_token(text) from public;
revoke all on function public.revoke_agent_token(uuid) from public;
grant execute on function public.mint_agent_token(text) to authenticated;
grant execute on function public.revoke_agent_token(uuid) to authenticated;

create or replace function public.add_agent_reminder(p_user_id uuid, p_text text)
returns table (
  id uuid,
  user_id uuid,
  text text,
  sort_order integer,
  is_done boolean,
  created_at timestamptz,
  completed_at timestamptz,
  capacity_maximum integer,
  active_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  trimmed text := trim(p_text);
  cap_max integer;
  active integer;
  next_order integer;
  inserted public.reminders%rowtype;
begin
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(trimmed) < 1 or char_length(trimmed) > 500 then
    raise exception 'LMR_INVALID_TEXT';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));

  select least(16, greatest(1, coalesce(
    (select prefs.max_lines from public.lock_screen_prefs as prefs where prefs.user_id = p_user_id),
    6
  )))
  into cap_max;

  select count(*) into active
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false;

  if active >= cap_max then
    raise exception 'LMR_CAPACITY_REACHED'
      using errcode = 'P0001',
            detail = cap_max::text;
  end if;

  select coalesce(max(reminders.sort_order), -1) + 1 into next_order
  from public.reminders as reminders
  where reminders.user_id = p_user_id;

  insert into public.reminders (user_id, text, sort_order)
  values (p_user_id, trimmed, next_order)
  returning * into inserted;

  return query
  select
    inserted.id,
    inserted.user_id,
    inserted.text,
    inserted.sort_order,
    inserted.is_done,
    inserted.created_at,
    inserted.completed_at,
    cap_max,
    active + 1;
end;
$$;

revoke all on function public.add_agent_reminder(uuid, text) from public, anon, authenticated;
grant execute on function public.add_agent_reminder(uuid, text) to service_role;
