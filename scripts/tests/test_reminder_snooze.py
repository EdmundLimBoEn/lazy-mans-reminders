"""Snooze regressions in the existing disposable local PostgreSQL fixture only."""
from pathlib import Path
import test_reopen_lock_order as baseline

ROOT = Path(__file__).resolve().parents[2]


class ReminderSnoozeTests(baseline.ReopenLockOrderTests):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # Vanilla PostgreSQL has no pg_cron: record schedules without running them.
        cls.sql("""
          create schema cron;
          create table cron.job(jobname text, schedule text, command text);
          create function cron.schedule(text,text,text) returns bigint language sql as $$
            insert into cron.job values ($1,$2,$3) returning 1::bigint $$;
        """)
        for name in ('20261113000200_usage_events.sql', '20261114001000_reminder_snooze.sql'):
            cls.sql((ROOT / 'supabase/migrations' / name).read_text())

    def test_snooze_sql(self):
        self.sql((ROOT / 'supabase/tests/reminder_snooze.sql').read_text())
        self.assertEqual(self.sql("select schedule from cron.job where jobname='clear-expired-reminder-snoozes'"), '* * * * *')

    def test_expiry_skips_locked_rows_and_retries(self):
        self.sql(f"update reminders set is_done=false, snoozed_until=now() - interval '1 minute' where id='{baseline.REMINDER}'")
        writer = self.process()
        try:
            writer.stdin.write(f"begin; select id from reminders where id='{baseline.REMINDER}' for update;\n\\echo LOCKED\n")
            writer.stdin.flush()
            while writer.stdout.readline().strip() != 'LOCKED':
                self.assertIsNone(writer.poll())
            self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '0')
            writer.communicate('commit;', timeout=5)
            self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '1')
        finally:
            if writer.poll() is None:
                writer.kill()
                writer.communicate()

    def test_budget_failure_is_retryable_and_other_owner_can_return(self):
        self.sql(f"""
          update reminders set is_done=false, snoozed_until=now() - interval '1 minute';
          update user_write_budgets set window_started_at=now() + interval '1 hour', writes=600
            where user_id='{baseline.OWNER}';
        """)
        self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '1')
        self.assertEqual(self.sql(f"select snoozed_until is not null from reminders where id='{baseline.REMINDER}'"), 't')
        self.sql(f"update user_write_budgets set window_started_at=now() - interval '1 hour' where user_id='{baseline.OWNER}'")
        self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '1')

    def test_expiry_does_not_wait_on_budget_lock(self):
        self.sql(f"update reminders set is_done=false, snoozed_until=now() - interval '1 minute' where id='{baseline.REMINDER}'")
        writer = self.process()
        try:
            writer.stdin.write(f"begin; select user_id from user_write_budgets where user_id='{baseline.OWNER}' for update;\n\\echo LOCKED\n")
            writer.stdin.flush()
            while writer.stdout.readline().strip() != 'LOCKED':
                self.assertIsNone(writer.poll())
            self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '0')
            writer.communicate('commit;', timeout=5)
            self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '1')
        finally:
            if writer.poll() is None:
                writer.kill()
                writer.communicate()

    def test_expiry_batch_is_bounded(self):
        self.sql(f"""
          insert into reminders(user_id, text, snoozed_until)
            select '{baseline.OWNER}', 'Sleeping ' || n, now() + interval '1 hour'
            from generate_series(1, 105) n;
          alter table reminders disable trigger reminders_enforce_quota;
          update reminders set snoozed_until=now() where text like 'Sleeping %';
          alter table reminders enable trigger reminders_enforce_quota;
        """)
        self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '100')
        self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '5')
        self.assertEqual(self.sql('select public.clear_expired_snoozes()'), '0')
