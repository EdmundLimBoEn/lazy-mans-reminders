-- Per-user Lock Screen Live Activity line budget, measured on the phone and
-- synced so the web board can match the banner capacity.

create table public.lock_screen_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  max_lines integer not null
    check (max_lines >= 1 and max_lines <= 20),
  point_size numeric(4, 1) not null default 15.0
    check (point_size >= 10 and point_size <= 28),
  updated_at timestamptz not null default now()
);

alter table public.lock_screen_prefs enable row level security;
alter table public.lock_screen_prefs force row level security;

create policy "Users can read their lock screen prefs"
  on public.lock_screen_prefs for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their lock screen prefs"
  on public.lock_screen_prefs for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their lock screen prefs"
  on public.lock_screen_prefs for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their lock screen prefs"
  on public.lock_screen_prefs for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create trigger lock_screen_prefs_set_updated_at
  before update on public.lock_screen_prefs
  for each row execute function public.set_updated_at();
