begin;

-- The scheduler stamps routine_fired_at and the completion trigger sets completed_at.
revoke insert, update on public.reminders from authenticated;
grant insert (id, user_id, text, sort_order, is_done, created_at, updated_at, routine_id),
      update (id, user_id, text, sort_order, is_done, created_at, updated_at, routine_id)
  on public.reminders to authenticated;

commit;
