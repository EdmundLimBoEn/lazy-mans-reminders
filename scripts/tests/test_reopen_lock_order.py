"""Run with PostgreSQL's bin directory on PATH; creates a disposable local cluster."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
OWNER = '00000000-0000-0000-0000-000000000001'
OTHER = '00000000-0000-0000-0000-000000000002'
REMINDER = '00000000-0000-0000-0000-000000000011'
ROUTINE = '00000000-0000-0000-0000-000000000021'


class ReopenLockOrderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ('initdb', 'pg_ctl', 'psql'):
            if not shutil.which(tool):
                raise RuntimeError(f'{tool} is required for the concurrent database regression')
        cls.temp = tempfile.TemporaryDirectory(prefix='lmr-reopen-')
        cls.data = cls.temp.name + '/data'
        cls.env = {**os.environ, 'PGHOST': cls.temp.name, 'PGPORT': '5432',
                   'PGDATABASE': 'postgres', 'PGUSER': 'postgres', 'PGPASSWORD': ''}
        subprocess.run(['initdb', '-D', cls.data, '-U', 'postgres', '-A', 'trust', '--no-locale'],
                       check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['pg_ctl', '-D', cls.data, '-l', cls.temp.name + '/server.log',
                        '-o', f"-k {cls.temp.name} -c listen_addresses=''", '-w', 'start'],
                       check=True, stdout=subprocess.DEVNULL)
        cls.addClassCleanup(cls.cleanup)
        cls.sql("""
          create role anon; create role authenticated; create role service_role bypassrls;
          create schema auth; create table auth.users(id uuid primary key);
          create function auth.uid() returns uuid language sql stable as $$
            select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
          grant usage on schema auth to authenticated, service_role;
          create publication supabase_realtime;
        """)
        for name in ('202608060001_create_reminders.sql', '202608080001_completed_at_and_cleanup.sql',
                     '202608060002_create_device_tokens.sql', '202608080002_lock_screen_prefs.sql',
                     '202608260001_agent_tokens.sql',
                     '202610120001_routine_reminders.sql', '202610220001_routine_ownership_and_overflow.sql',
                     '202610220003_reminder_quotas.sql', '202610280002_reminder_quota_capacity.sql',
                     '202610280002_preserve_pending_routine_firings.sql',
                     '202610280002_reopen_reminder_lock_order.sql',
                     '20261101000300_reopen_reminder_noop.sql',
                     '202610280001_write_budgets.sql',
                     '20261101000100_agent_token_revocation_budget.sql',
                     '20261109000100_scheduler_reminder_nowait.sql'):
            source = (ROOT / 'supabase/migrations' / name).read_text()
            # This isolated vanilla PostgreSQL cluster has no Supabase cron or crypto extensions.
            source = '\n'.join(line for line in source.splitlines()
                               if not line.startswith(('create extension', 'select cron.schedule')))
            cls.sql(source)
        cls.sql(f"""
          grant select, insert, update, delete on public.reminders to authenticated, service_role;
          insert into auth.users values ('{OWNER}'), ('{OTHER}');
        """)

    def setUp(self):
        # Commit fresh fixtures so both concurrent psql sessions can see them.
        self.sql(f"""
          begin;
          delete from public.reminders;
          delete from public.routine_reminders;
          insert into public.routine_reminders(id,user_id,text,interval_days,start_date,local_time,timezone)
            values ('{ROUTINE}','{OWNER}','Routine',1,current_date,'09:00','UTC');
          update public.routine_reminders set next_run_at = now() - interval '1 minute';
          insert into public.reminders(id,user_id,text,is_done,routine_id)
            values ('{REMINDER}','{OWNER}','Completed',true,'{ROUTINE}');
          insert into public.reminders(id,user_id,text,is_done)
            values ('{OTHER}','{OTHER}','Other owner',true);
          commit;
        """)

    @classmethod
    def cleanup(cls):
        subprocess.run(['pg_ctl', '-D', cls.data, '-m', 'immediate', '-w', 'stop'],
                       check=True, stdout=subprocess.DEVNULL)
        cls.temp.cleanup()

    @classmethod
    def process(cls):
        return subprocess.Popen(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], env=cls.env,
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)

    @classmethod
    def sql(cls, statement):
        process = cls.process()
        out, err = process.communicate(statement, timeout=10)
        if process.returncode:
            raise AssertionError(err)
        return out.strip()

    def test_concurrent_scheduler_and_reopen(self):
        scheduler = self.process()
        reopen = None
        try:
            scheduler.stdin.write(f"begin; select pg_advisory_xact_lock(hashtextextended('{OWNER}',0));\n\\echo LOCKED\n")
            scheduler.stdin.flush()
            while scheduler.stdout.readline().strip() != 'LOCKED':
                self.assertIsNone(scheduler.poll())
            reopen = self.process()
            reopen.stdin.write(f"set application_name='reopen-regression'; set role authenticated; "
                               f"set request.jwt.claim.sub='{OWNER}'; "
                               f"select count(*) from public.reopen_reminder('{OWNER}','{REMINDER}');\n")
            reopen.stdin.flush()
            deadline = time.monotonic() + 5
            while self.sql("select count(*) from pg_stat_activity where application_name='reopen-regression' and wait_event='advisory'") != '1':
                self.assertLess(time.monotonic(), deadline, 'Reopen never waited on the owner lock')
                time.sleep(.02)
            # If reopening already holds the reminder row, the scheduler deadlocks here.
            out, err = scheduler.communicate('select public.fire_due_routines(); commit;\n', timeout=10)
            self.assertEqual(scheduler.returncode, 0, err)
            self.assertEqual(out.strip(), '1', err)
            out, err = reopen.communicate(timeout=10)
            self.assertEqual(reopen.returncode, 0, err)
            self.assertEqual(out.strip(), '1', err)
            self.assertEqual(self.sql(f"select not is_done and completed_at is null from reminders where id='{REMINDER}'"), 't')
        finally:
            for process in (scheduler, reopen):
                if process and process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_ownership_permissions_and_quota(self):
        self.assertEqual(self.sql("select has_function_privilege('anon','public.reopen_reminder(uuid,uuid,text)','execute')"), 'f')
        for owner, reminder in ((OTHER, OTHER), (OWNER, OTHER)):
            self.assertEqual(self.sql(f"set role authenticated; set request.jwt.claim.sub='{OWNER}'; select count(*) from public.reopen_reminder('{owner}','{reminder}')"), '0')
        self.assertEqual(self.sql(f"set role service_role; select count(*) from public.reopen_reminder('{OTHER}','{REMINDER}')"), '0')
        self.assertEqual(self.sql(f"set role service_role; select text from public.reopen_reminder('{OWNER}','{REMINDER}','Edited')"), 'Edited')
        self.sql(f"update reminders set is_done=true where id='{REMINDER}'; insert into reminders(user_id,text) select '{OWNER}','Slot' from generate_series(1,16)")
        with self.assertRaisesRegex(AssertionError, 'at most 16 active reminders'):
            self.sql(f"set role authenticated; set request.jwt.claim.sub='{OWNER}'; select * from public.reopen_reminder('{OWNER}','{REMINDER}')")
        self.assertEqual(self.sql(f"select is_done from reminders where id='{REMINDER}'"), 't')

    def test_scheduler_skips_concurrent_completion_and_retries(self):
        blocked_routine = '00000000-0000-0000-0000-000000000022'
        later_routine = '00000000-0000-0000-0000-000000000023'
        self.sql(f"""
          insert into routine_reminders(id,user_id,text,interval_days,start_date,local_time,timezone)
            values ('{blocked_routine}','{OWNER}','Completing',1,current_date,'09:00','UTC'),
                   ('{later_routine}','{OWNER}','Later',1,current_date,'09:00','UTC');
          update routine_reminders set next_run_at = now() - interval '3 minutes' where id='{ROUTINE}';
          update routine_reminders set next_run_at = now() - interval '2 minutes' where id='{blocked_routine}';
          update routine_reminders set next_run_at = now() - interval '1 minute' where id='{later_routine}';
          insert into reminders(user_id,text,routine_id)
            values ('{OWNER}','Completing','{blocked_routine}');
          -- Pause the actual batch after A has fired and retained the budget lock.
          create function public.pause_scheduler_test() returns trigger language plpgsql as $$
          begin
            if new.id = '{ROUTINE}' then perform pg_advisory_xact_lock(71001); end if;
            return null;
          end $$;
          create trigger zzz_pause_scheduler_test after update on routine_reminders
            for each row execute function public.pause_scheduler_test();
        """)
        due_before = self.sql(f"select next_run_at from routine_reminders where id='{blocked_routine}'")
        gate, scheduler, completion = self.process(), self.process(), self.process()

        def wait_for(query, message):
            deadline = time.monotonic() + 5
            while self.sql(query) != 't':
                self.assertLess(time.monotonic(), deadline, message)
                time.sleep(.02)

        try:
            gate.stdin.write("select pg_advisory_lock(71001);\n\\echo LOCKED\n")
            gate.stdin.flush()
            while gate.stdout.readline().strip() != 'LOCKED':
                self.assertIsNone(gate.poll())
            scheduler.stdin.write("set application_name='scheduler-budget-regression'; "
                                  "select public.fire_due_routines();\n")
            scheduler.stdin.flush()
            wait_for("select exists (select 1 from pg_stat_activity where "
                     "application_name='scheduler-budget-regression' and wait_event='advisory')",
                     'Scheduler never reached the first firing')
            completion.stdin.write(f"set application_name='completion-budget-regression'; "
                                   "set deadlock_timeout='10s'; set role authenticated; "
                                   f"set request.jwt.claim.sub='{OWNER}'; "
                                   f"update reminders set is_done=true where routine_id='{blocked_routine}';\n")
            completion.stdin.flush()
            wait_for("select exists (select 1 from pg_stat_activity c, pg_stat_activity s where "
                     "c.application_name='completion-budget-regression' and "
                     "s.application_name='scheduler-budget-regression' and "
                     "c.wait_event='transactionid' and s.pid=any(pg_blocking_pids(c.pid)))",
                     'Completion never held B while waiting for the scheduler budget')
            gate.communicate('select pg_advisory_unlock(71001);\n', timeout=10)
            out, err = scheduler.communicate(timeout=10)
            self.assertEqual(scheduler.returncode, 0, err)
            # Without NOWAIT the batch warns with SQLSTATE 40P01, or completion aborts.
            self.assertEqual(err.strip(), '', err)
            self.assertEqual(out.strip(), '2', 'A and the later routine must fire; B must stay due')
            out, err = completion.communicate(timeout=10)
            self.assertEqual(completion.returncode, 0, err)
            self.assertEqual(self.sql(f"select next_run_at from routine_reminders where id='{blocked_routine}'"), due_before)
            self.assertEqual(self.sql(f"select is_done and routine_fired_at is null from reminders where routine_id='{blocked_routine}'"), 't')
            self.assertEqual(self.sql('select public.fire_due_routines()'), '1')
            self.assertEqual(self.sql(f"select not is_done and completed_at is null and routine_fired_at is not null from reminders where routine_id='{blocked_routine}'"), 't')
            self.assertEqual(self.sql(f"select next_run_at > now() from routine_reminders where id='{blocked_routine}'"), 't')
            self.assertEqual(self.sql('select public.fire_due_routines()'), '0')
        finally:
            for process in (gate, scheduler, completion):
                if process.poll() is None:
                    process.kill()
                    process.communicate()
            self.sql('drop trigger zzz_pause_scheduler_test on routine_reminders; drop function public.pause_scheduler_test()')


class ReopenFixtureIsolationTests(unittest.TestCase):
    def test_orders_and_repeated_scheduler(self):
        concurrency = 'test_concurrent_scheduler_and_reopen'
        quota = 'test_ownership_permissions_and_quota'
        for order in ((quota, concurrency, concurrency), (concurrency, quota, concurrency)):
            with self.subTest(order=order):
                # Keep one cluster for each sequence, exercising unittest's real setup lifecycle.
                suite = unittest.TestSuite(ReopenLockOrderTests(name) for name in order)
                result = unittest.TestResult()
                suite.run(result)
                self.assertEqual(result.errors, [])
                self.assertEqual(result.failures, [])
                self.assertEqual(result.testsRun, len(order))


if __name__ == '__main__':
    unittest.main()
