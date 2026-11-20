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
      const predicates: Array<(row: Row) => boolean> = [];
      let deleting = false;
      const query = {
        delete() {
          deleting = true;
          return query;
        },
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
        gt(column: "updated_at", value: string) {
          predicates.push((row) => Date.parse(row[column]) > Date.parse(value));
          return query;
        },
        select() {
          return query;
        },
        maybeSingle() {
          const index = rows.findIndex((row) =>
            predicates.every((matches) => matches(row))
          );
          const data = index < 0 ? null : rows[index];
          if (data && deleting) rows.splice(index, 1);
          return Promise.resolve({ data, error: null });
        },
      };
      return query;
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
      assertEquals(await run, refreshed ? "retryable" : "pruned");
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
    const newer = {
      ...row,
      updated_at: new Date(invalidation + 2).toISOString(),
    };
    const otherDevice = { ...newer, token: "other-device" };
    const otherOwner = { ...newer, user_id: "other-owner" };
    const rows = [row, otherDevice, otherOwner];
    const result = await deliverWithRetries({
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
    assertEquals(result, offset > 0 ? "invalid" : "pruned");
    assertEquals(
      rows,
      offset > 0 ? [row, otherDevice, otherOwner] : [
        otherDevice,
        otherOwner,
      ],
    );
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
