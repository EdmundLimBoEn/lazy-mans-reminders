import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { reconcileLiveActivity } from "./live_activity_lifecycle.ts";
import { markActivityEnded } from "./live_activity_store.ts";

type Row = {
  token: string;
  user_id: string;
  activity_push_token: string | null;
  activity_started_at: string | null;
};
const oldStart = "2026-10-22T00:00:00Z";
const newStart = "2026-10-22T01:00:00Z";

// Apply the update only when all PostgREST filters match the current row.
function client(rows: Row[]) {
  return {
    from(table: string) {
      assertEquals(table, "device_tokens");
      return {
        update(patch: Partial<Row>) {
          const predicates: Array<(row: Row) => boolean> = [];
          const query = {
            eq(column: keyof Row, value: string) {
              predicates.push((row) =>
                row[column] !== null && row[column] === value
              );
              return query;
            },
            is(column: keyof Row, value: null) {
              predicates.push((row) => row[column] === value);
              return query;
            },
            then(resolve: (value: { error: null }) => unknown) {
              for (const row of rows) {
                if (predicates.every((matches) => matches(row))) {
                  Object.assign(row, patch);
                }
              }
              return Promise.resolve({ error: null }).then(resolve);
            },
          };
          return query;
        },
      };
    },
  };
}

for (const token of ["old-token", null]) {
  for (const startedAt of [oldStart, null]) {
    for (const change of ["none", "token", "start", "both"] as const) {
      Deno.test(`empty board cleanup: token=${token}, start=${startedAt}, concurrent change=${change}`, async () => {
        const row: Row = {
          token: "device",
          user_id: "user",
          activity_push_token: token,
          activity_started_at: startedAt,
        };
        const observed = { ...row };
        const otherDevice = { ...row, token: "other-device" };
        const otherUser = { ...row, user_id: "other-user" };
        const untouched = [{ ...otherDevice }, { ...otherUser }];
        const db = client([row, otherDevice, otherUser]);
        const sending = Promise.withResolvers<void>();
        const response = Promise.withResolvers<"sent">();
        const run = reconcileLiveActivity({
          lines: [], activityToken: token, startedAt, startToken: null,
          // With no current token, cleanup awaits ending the retiring activity.
          retiringToken: token === null ? "retiring-token" : null,
          nowMs: Date.parse(newStart), hasAlert: false,
          send: (event, destination) => {
            assertEquals(event, "end");
            assertEquals(destination, token === null ? "retiring" : "activity");
            sending.resolve();
            return response.promise;
          },
          recordEnd: () => markActivityEnded(
            db, observed.user_id, observed.token,
            observed.activity_push_token, observed.activity_started_at,
          ),
          recordStart: () => { throw new Error("unexpected start"); },
          recordAdoption: () => { throw new Error("unexpected adoption"); },
          clearRetiring: () => Promise.resolve(),
        });
        await sending.promise;
        if (change === "token" || change === "both") {
          row.activity_push_token = "replacement-token";
        }
        if (change === "start" || change === "both") {
          row.activity_started_at = newStart;
        }
        const expected = change === "none"
          ? { ...row, activity_push_token: null, activity_started_at: null }
          : { ...row };
        response.resolve("sent");
        assertEquals(await run, { results: ["sent"], deliveredAlert: false });
        assertEquals(row, expected);
        assertEquals([otherDevice, otherUser], untouched);
      });
    }
  }
}
