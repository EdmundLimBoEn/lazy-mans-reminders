import {
  assertEquals,
  assertFalse,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  LIVE_ACTIVITY_ATTRIBUTES_TYPE,
  LIVE_ACTIVITY_FALLBACK_MAX_LINES,
  LIVE_ACTIVITY_RECYCLE_AFTER_MS,
  LIVE_ACTIVITY_START_GRACE_MS,
  LIVE_ACTIVITY_TOKEN_PATTERN,
  boardLines,
  buildLiveActivityHeaders,
  buildLiveActivityPayload,
  decideLiveActivity,
  liveActivityStaleDateUnix,
  liveActivityTopic,
  parseLiveActivityToken,
  parseStartedAtMs,
} from "./live_activity.ts";

Deno.test("boardLines matches the iOS empty / cap / newline rules", () => {
  assertEquals(boardLines([], LIVE_ACTIVITY_FALLBACK_MAX_LINES), []);
  assertEquals(boardLines(["  ", "\n"], 6), []);
  assertEquals(boardLines(["Book dentist"], 6), ["Book dentist"]);
  assertEquals(
    boardLines(["a\nb\nc", "d"], 3),
    ["a", "b", "+2 more"],
  );
  const six = ["0", "1", "2", "3", "4", "5"];
  assertEquals(boardLines(six, 3), ["0", "1", "+4 more"]);
});

Deno.test("decideLiveActivity ends only when the board is empty", () => {
  assertEquals(
    decideLiveActivity({
      lines: [],
      hasPushToStartToken: true,
      hasActivityToken: true,
      startedAtMs: 1,
      nowMs: 2,
    }),
    { kind: "end" },
  );
  assertEquals(
    decideLiveActivity({
      lines: [],
      hasPushToStartToken: true,
      hasActivityToken: false,
      startedAtMs: null,
      nowMs: 2,
    }),
    { kind: "noop" },
  );
});

Deno.test("decideLiveActivity starts from push-to-start without an open activity", () => {
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: true,
      hasActivityToken: false,
      startedAtMs: null,
      nowMs: 10_000,
    }),
    { kind: "start" },
  );
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: false,
      hasActivityToken: false,
      startedAtMs: null,
      nowMs: 10_000,
    }),
    { kind: "noop" },
  );
});

Deno.test("decideLiveActivity updates while the current activity is young", () => {
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: true,
      hasActivityToken: true,
      startedAtMs: 1_000,
      nowMs: 1_000 + 60_000,
    }),
    { kind: "update" },
  );
});

Deno.test("decideLiveActivity waits out the start-token grace window", () => {
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: true,
      hasActivityToken: false,
      startedAtMs: 1_000,
      nowMs: 1_000 + LIVE_ACTIVITY_START_GRACE_MS - 1,
    }),
    { kind: "noop" },
  );
});

Deno.test("decideLiveActivity recycles before the 8h Apple cap", () => {
  const startedAtMs = 1_000;
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: true,
      hasActivityToken: true,
      startedAtMs,
      nowMs: startedAtMs + LIVE_ACTIVITY_RECYCLE_AFTER_MS,
    }),
    { kind: "recycle" },
  );
  assertEquals(
    decideLiveActivity({
      lines: ["Milk"],
      hasPushToStartToken: false,
      hasActivityToken: true,
      startedAtMs,
      nowMs: startedAtMs + LIVE_ACTIVITY_RECYCLE_AFTER_MS,
    }),
    { kind: "update" },
  );
});

Deno.test("decideLiveActivity recovers legacy activity tokens with unknown age", () => {
  for (const hasPushToStartToken of [true, false]) {
    assertEquals(
      decideLiveActivity({
        lines: ["Milk"],
        hasPushToStartToken,
        hasActivityToken: true,
        startedAtMs: null,
        nowMs: 10_000,
      }),
      { kind: hasPushToStartToken ? "recycle" : "update" },
    );
  }
});

Deno.test("start payload is ReminderAttributes with an alert and lines", () => {
  const body = JSON.parse(buildLiveActivityPayload({
    event: "start",
    lines: ["Milk", "Eggs"],
    timestamp: 1_775_000_000,
    alertBody: "Milk",
    staleDate: 1_775_028_800,
  }));
  assertEquals(body.aps.event, "start");
  assertEquals(body.aps["input-push-token"], 1);
  assertEquals(body.aps["attributes-type"], LIVE_ACTIVITY_ATTRIBUTES_TYPE);
  assertEquals(body.aps.attributes, {});
  assertEquals(body.aps["content-state"], { lines: ["Milk", "Eggs"] });
  assertEquals(body.aps.alert, { body: "Milk" });
  assertEquals(body.aps["stale-date"], 1_775_028_800);
});

Deno.test("update and end payloads do not request a new push token", () => {
  for (const event of ["update", "end"] as const) {
    const body = JSON.parse(buildLiveActivityPayload({
      event,
      lines: ["Milk"],
      timestamp: 1_775_000_000,
      staleDate: 1_775_028_800,
    }));
    assertFalse("input-push-token" in body.aps);
  }
});

Deno.test("end payload dismisses immediately", () => {
  const body = JSON.parse(buildLiveActivityPayload({
    event: "end",
    lines: [],
    timestamp: 1_775_000_000,
    staleDate: 1_775_000_000,
  }));
  assertEquals(body.aps.event, "end");
  assertEquals(body.aps["dismissal-date"], 1);
  assertEquals(body.aps["content-state"], { lines: [] });
});

Deno.test("live activity APNs headers use the liveactivity topic", () => {
  const headers = buildLiveActivityHeaders({
    jwt: "token",
    bundleId: "systems.edmundlim.LazyMansReminders",
  });
  assertEquals(
    headers["apns-topic"],
    "systems.edmundlim.LazyMansReminders.push-type.liveactivity",
  );
  assertEquals(headers["apns-push-type"], "liveactivity");
  assertEquals(headers["apns-priority"], "10");
  assertEquals(
    liveActivityTopic("systems.edmundlim.LazyMansReminders"),
    headers["apns-topic"],
  );
});

Deno.test("live activity token parse rejects alert-device-token lookalikes that are too short", () => {
  assertMatch("a".repeat(64), LIVE_ACTIVITY_TOKEN_PATTERN);
  assertEquals(parseLiveActivityToken("a".repeat(64)), "a".repeat(64));
  assertEquals(parseLiveActivityToken("a".repeat(80)), "a".repeat(80));
  assertEquals(parseLiveActivityToken("a".repeat(63)), null);
  assertEquals(parseLiveActivityToken("nope"), null);
  assertFalse(LIVE_ACTIVITY_TOKEN_PATTERN.test("g".repeat(64)));
});

Deno.test("parseStartedAtMs and stale-date helpers", () => {
  assertEquals(parseStartedAtMs("2026-08-28T00:00:00.000Z"), Date.parse("2026-08-28T00:00:00.000Z"));
  assertEquals(parseStartedAtMs("not-a-date"), null);
  assertEquals(liveActivityStaleDateUnix(1_000), 1_000 + 8 * 60 * 60);
});
