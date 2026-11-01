import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { type PushJob, pushReplay } from "./push_replay.ts";
import { reconcileLiveActivity } from "./live_activity_lifecycle.ts";

function fixture() {
  let stored: PushJob = {
    id: "job",
    user_id: "owner",
    device_token: "device",
    payload: {},
    status: "pending",
    outcomes: {},
    alert_sent: false,
  };
  let fail = false;
  const supabase = {
    rpc: () => Promise.resolve({ data: null, error: null }),
    from: (_table: string) => ({
      update: (patch: Partial<PushJob>) => {
        const query = {
          eq: () => query,
          select: () => query,
          maybeSingle: () => {
            if (fail) return Promise.resolve({ data: null, error: "offline" });
            stored = { ...stored, ...structuredClone(patch) };
            return Promise.resolve({ data: { id: stored.id }, error: null });
          },
        };
        return query;
      },
    }),
  };
  return {
    restart: () => pushReplay(supabase, structuredClone(stored), () => {}),
    read: () => stored,
    failWrites: () => {
      fail = true;
    },
  };
}

Deno.test("restart retries transient device operations and skips persisted successes", async () => {
  const a = fixture();
  const b = fixture();
  let sends = 0;
  const success = () => {
    sends++;
    return Promise.resolve("sent" as const);
  };
  const firstA = a.restart();
  await firstA.send("alert", true, success);
  await firstA.finish(["sent"]);
  const firstB = b.restart();
  await firstB.send("alert", true, () => Promise.resolve("retryable"));
  await firstB.finish(["retryable"]);
  assertEquals(a.read().status, "complete");
  assertEquals(b.read().status, "pending");
  await a.restart().send("alert", true, success);
  const secondB = b.restart();
  await secondB.send("alert", true, success);
  await secondB.finish(["sent"]);
  assertEquals(sends, 2);
  assertEquals(b.read().status, "complete");
});

Deno.test("successful fallback alert survives restart while live delivery remains retryable", async () => {
  const f = fixture();
  const first = f.restart();
  await first.send(
    "live:activity:update",
    true,
    () => Promise.resolve("retryable"),
  );
  await first.send("alert", true, () => Promise.resolve("sent"));
  await first.finish(["retryable", "sent"]);
  const next = f.restart();
  assertEquals(next.alertSent, true); // caller suppresses alert body on the live retry
  await next.send(
    "live:activity:update",
    !next.alertSent,
    () => Promise.resolve("sent"),
  );
  await next.send("alert", true, () => {
    throw new Error("duplicate alert");
  });
  await next.finish(["sent"]);
  assertEquals(f.read().status, "complete");
});

Deno.test("persisted live acceptance survives a subsequent bookkeeping exception", async () => {
  const f = fixture();
  await f.restart().send(
    "live:push-to-start:start",
    true,
    () => Promise.resolve("sent"),
  );
  // Simulate a crash before lifecycle bookkeeping or finishing the job.
  const next = f.restart();
  assertEquals(next.alertSent, true);
  assertEquals(
    await next.send("live:push-to-start:start", true, () => {
      throw new Error("must not start twice");
    }),
    "sent",
  );
});

Deno.test("terminal rejection is not replayed and failed persistence leaves the job pending", async () => {
  const f = fixture();
  await f.restart().send("alert", true, () => Promise.resolve("invalid"));
  assertEquals(
    await f.restart().send("alert", true, () => {
      throw new Error("must not retry invalid token");
    }),
    "invalid",
  );
  f.failWrites();
  await assertRejects(() => f.restart().finish(["invalid"]));
  assertEquals(f.read().status, "pending");
});

for (const activityToken of [null, "activity"]) {
  Deno.test(`accepted live ${activityToken ? "update" : "start"} suppresses fallback when persistence fails`, async () => {
    const f = fixture();
    const replay = f.restart();
    f.failWrites();
    const sends: string[] = [];
    const live = await reconcileLiveActivity({
      lines: ["Milk"],
      activityToken,
      startToken: "start",
      retiringToken: null,
      startedAt: activityToken ? new Date(0).toISOString() : null,
      nowMs: 1000,
      hasAlert: true,
      send: (event, destination) =>
        replay.send(`live:${destination}:${event}`, true, () => {
          sends.push(event);
          return Promise.resolve("sent");
        }),
      claimStart: () => Promise.resolve("lease"),
      releaseStart: () => Promise.resolve(),
      recordStart: () => Promise.resolve(),
      recordEnd: () => Promise.resolve(),
      recordAdoption: () => Promise.resolve(),
      clearRetiring: () => Promise.resolve(),
    });
    // Same fallback guard used by send-reminder-push.
    if (!live.deliveredAlert && !replay.alertSent) sends.push("fallback");
    await replay.finish(live.results);
    assertEquals(sends, [activityToken ? "update" : "start"]);
    assertEquals(live.results, ["retryable"]);
    assertEquals(replay.alertSent, true);
    assertEquals(f.read().alert_sent, false);
    assertEquals(f.read().status, "pending");
  });
}

for (const result of ["sent", "retryable", "failed", "invalid"] as const) {
  Deno.test(`failed persistence does not mark a non-alert ${result} as accepted`, async () => {
    const f = fixture();
    const replay = f.restart();
    f.failWrites();
    await assertRejects(
      () =>
        replay.send("live:retiring:end", false, () => Promise.resolve(result)),
      Error,
      "Could not save push delivery progress",
    );
    assertEquals(replay.alertSent, false);
  });
}
