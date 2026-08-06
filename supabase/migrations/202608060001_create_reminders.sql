create extension if not exists pgcrypto;

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null check (char_length(trim(text)) between 1 and 500),
  sort_order integer not null default 0,
  is_done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index reminders_user_active_order_idx
  on public.reminders (user_id, is_done, sort_order, created_at);

alter table public.reminders enable row level security;
alter table public.reminders force row level security;

create policy "Users can read their reminders"
  on public.reminders for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their reminders"
  on public.reminders for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their reminders"
  on public.reminders for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their reminders"
  on public.reminders for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public;

create trigger reminders_set_updated_at
  before update on public.reminders
  for each row execute function public.set_updated_at();

alter publication supabase_realtime add table public.reminders;
