import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { pruneAlertToken } from "./alert_token_store.ts";
import {
  type ApnsOutcome,
  classifyApnsResponse,
  deliverWithRetries,
} from "./push_helpers.ts";

type Row = {
  token: string;
  user_id: string;
  updated_at: string;
  activity_push_token: string;
};
const registration = "2026-10-28T00:00:00.000Z";
const invalidation = Date.parse(registration) + 1000;

function client(rows: Row[]) {
  return {
    from(table: string) {
      assertEquals(table, "device_tokens");
      return {
        delete() {
          const predicates: Array<(row: Row) => boolean> = [];
          const query = {
            eq(column: keyof Row, value: string) {
              predicates.push((row) => row[column] === value);
              return query;
            },
            lte(column: "updated_at", value: string) {
              predicates.push((row) =>
                Date.parse(row[column]) <= Date.parse(value)
              );
              return query;
            },
            then(resolve: (value: { error: null }) => unknown) {
              for (let i = rows.length - 1; i >= 0; i--) {
                if (predicates.every((matches) => matches(rows[i]))) {
                  rows.splice(i, 1);
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

for (const status of [400, 410]) {
  for (const refreshed of [false, true]) {
    Deno.test(`APNs ${status} rejection protects concurrent registration: ${refreshed}`, async () => {
      const row: Row = {
        token: "device",
        user_id: "owner",
        updated_at: registration,
        activity_push_token: "old",
      };
      const observed = { ...row };
      const otherDevice = { ...row, token: "other-device" };
      const otherOwner = { ...row, user_id: "other-owner" };
      const rows = [row, otherDevice, otherOwner];
      const sending = Promise.withResolvers<void>();
      const response = Promise.withResolvers<ApnsOutcome>();
      const run = deliverWithRetries({
        headers: {},
        send: () => {
          sending.resolve();
          return response.promise;
        },
        nextJwt: () => Promise.resolve("unused"),
        onExpiredJwt: () => {},
        onPrune: (outcome) => pruneAlertToken(client(rows), observed, outcome),
        sleep: () => Promise.resolve(),
      });
      await sending.promise;
      if (refreshed) {
        // Even a refresh before APNs's invalidation time changes the revision.
        row.updated_at = new Date(invalidation - 1).toISOString();
        row.activity_push_token = "fresh";
      }
      const expected = refreshed
        ? [{ ...row }, otherDevice, otherOwner]
        : [otherDevice, otherOwner];
      response.resolve(classifyApnsResponse(
        status,
        JSON.stringify({
          reason: status === 410 ? "Unregistered" : "BadDeviceToken",
          timestamp: invalidation,
        }),
      ));
      assertEquals(await run, "invalid");
      assertEquals(rows, expected);
    });
  }
}

for (const offset of [-1, 0, 1]) {
  Deno.test(`APNs invalidation compares registration time: offset ${offset}ms`, async () => {
    const row: Row = {
      token: "device",
      user_id: "owner",
      updated_at: new Date(invalidation + offset).toISOString(),
      activity_push_token: "activity",
    };
    const rows = [row];
    await deliverWithRetries({
      headers: {},
      send: () =>
        Promise.resolve(
          classifyApnsResponse(
            410,
            JSON.stringify({ reason: "Unregistered", timestamp: invalidation }),
          ),
        ),
      nextJwt: () => Promise.resolve("unused"),
      onExpiredJwt: () => {},
      onPrune: (outcome) => pruneAlertToken(client(rows), { ...row }, outcome),
      sleep: () => Promise.resolve(),
    });
    assertEquals(rows, offset > 0 ? [row] : []);
  });
}

Deno.test("APNs timestamp parser preserves milliseconds and rejects malformed timestamps", () => {
  assertEquals(
    classifyApnsResponse(
      410,
      JSON.stringify({ reason: "Unregistered", timestamp: invalidation }),
    ),
    {
      kind: "prune",
      status: 410,
      reason: "Unregistered",
      invalidatedAtMs: invalidation,
    },
  );
  for (const timestamp of [undefined, null, "123", -1, 1.5, 1e100]) {
    assertEquals(
      classifyApnsResponse(
        410,
        JSON.stringify({ reason: "Unregistered", timestamp }),
      ),
      {
        kind: "prune",
        status: 410,
        reason: "Unregistered",
      },
    );
  }
});
