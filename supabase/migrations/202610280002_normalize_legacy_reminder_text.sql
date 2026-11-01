begin;

-- NOT VALID still checks completion/reorder updates of legacy rows. Their
-- existing trimmed-length constraint guarantees trim(text) fits without loss.
-- Hold the table lock while suppressing application triggers so this repair
-- neither spends write budgets nor queues pushes or changes edit timestamps.
alter table public.reminders disable trigger user;

update public.reminders
set text = trim(text)
where char_length(text) > 1000;

alter table public.reminders validate constraint reminders_text_raw_length;
alter table public.reminders enable trigger user;

commit;
