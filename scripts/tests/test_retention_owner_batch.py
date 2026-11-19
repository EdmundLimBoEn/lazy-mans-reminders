"""Exercise the hourly cleanup on a backlog spanning multiple transactions."""
from test_api_table_grants import _DisposableDatabase


class RetentionOwnerBatchTests(_DisposableDatabase):
    def test_owner_locks_and_committed_progress(self):
        self.sql("""
          with owners as (
            insert into auth.users (id)
            select md5(n::text)::uuid from generate_series(1, 65) n
            returning id
          )
          insert into public.reminders (user_id, text, is_done, completed_at)
          select id, 'Expired', true, now() - interval '4 days' from owners;
        """)

        # A fixed UUID prefix would spend the entire batch on exhausted owners.
        self.sql("""
          begin;
          update public.user_write_budgets set writes = 600, window_started_at = now() + interval '1 hour'
          where user_id in (select user_id from public.reminders order by user_id limit 32);
          select setseed(0.5);
          do $$ begin
            assert public.delete_old_completed_reminders() > 0, 'Later owners must get a turn';
          end $$;
          rollback;
        """)

        remaining = 65
        for batch in (32, 32, 1):
            self.sql(f"""
              do $$ declare deleted integer; begin
                assert (select count(*) = {remaining} from public.reminders),
                  'Previous cleanup must have committed its deletes';
                deleted := public.delete_old_completed_reminders();
                assert (select count(*) <= 32 from pg_locks
                        where locktype = 'advisory' and pid = pg_backend_pid() and granted),
                  'Cleanup retained more than 32 owner locks';
                assert deleted = {batch}, 'Cleanup must drain the next owner batch';
              end $$;
            """)
            remaining -= batch
        self.sql("do $$ begin assert not exists (select from public.reminders); end $$;")
