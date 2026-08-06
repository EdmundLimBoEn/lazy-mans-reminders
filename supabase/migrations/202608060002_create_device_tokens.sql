create table public.device_tokens (
  token text primary key
    check (token ~ '^[0-9A-Fa-f]{64}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  environment text not null default 'production'
    check (environment in ('development', 'production')),
  updated_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;
alter table public.device_tokens force row level security;

create policy "Users can read their device tokens"
  on public.device_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can register their devices"
  on public.device_tokens for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their devices"
  on public.device_tokens for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can remove their devices"
  on public.device_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();
