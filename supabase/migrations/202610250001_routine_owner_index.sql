-- Support owner-filtered loading in creation order and routine quota counts.
create index routine_reminders_user_created_idx
  on public.routine_reminders(user_id, created_at);
