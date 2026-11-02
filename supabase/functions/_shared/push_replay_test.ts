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

for (const activityToken of [null, "old"]) {
  Deno.test(`busy ${activityToken ? "renewal" : "initial start"} lease keeps the job pending until a later retry succeeds`, async () => {
    const f = fixture();
    // Dispatch at t=0 schedules a retry at t=120, but the worker only claims
    // its two-minute start lease at t=10, so that lease expires at t=130.
    let nowMs = 10_000;
    let leaseExpiresAt = 0;
    let starts = 0;
    let alerts = 0;
    let recordings = 0;
    let releases = 0;
    const run = async () => {
      const replay = f.restart();
      const hasAlert = !replay.alertSent;
      const live = await reconcileLiveActivity({
        lines: ["Milk"],
        activityToken,
        startToken: "start",
        retiringToken: null,
        startedAt: activityToken
          ? new Date(-7 * 60 * 60 * 1000).toISOString()
          : null,
        nowMs,
        hasAlert,
        claimStart: () => {
          if (nowMs < leaseExpiresAt) return Promise.resolve(null);
          leaseExpiresAt = nowMs + 120_000;
          return Promise.resolve("lease");
        },
        send: (event, destination) =>
          replay.send(`live:${destination}:${event}`, hasAlert, () => {
            starts++;
            return Promise.resolve(starts === 1 ? "retryable" : "sent");
          }, "start"),
        releaseStart: () => {
          releases++;
          return Promise.resolve();
        },
        recordStart: () => {
          recordings++;
          return Promise.resolve();
        },
        recordEnd: () => Promise.resolve(),
        recordAdoption: () => Promise.resolve(),
        clearRetiring: () => Promise.resolve(),
      });
      const results = [...live.results];
      if (!live.deliveredAlert && !replay.alertSent) {
        results.push(
          await replay.send("alert", true, () => {
            alerts++;
            return Promise.resolve("sent");
          }),
        );
      }
      await replay.finish(results);
    };

    await run();
    assertEquals(f.read().status, "pending");
    assertEquals({ starts, alerts, recordings, releases }, {
      starts: 1,
      alerts: 1,
      recordings: 0,
      releases: 0,
    });

    nowMs = 121_000;
    await run();
    assertEquals(f.read().status, "pending");
    assertEquals({ starts, alerts, recordings, releases }, {
      starts: 1,
      alerts: 1,
      recordings: 0,
      releases: 0,
    });

    nowMs = 361_000;
    await run();
    assertEquals(f.read().status, "complete");
    assertEquals({ starts, alerts, recordings, releases }, {
      starts: 2,
      alerts: 1,
      recordings: 1,
      releases: 0,
    });
  });
}

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

for (const destination of ["activity", "retiring"] as const) {
  Deno.test(`replayed end must send to replacement ${destination} before clearing it`, async () => {
    const f = fixture();
    const sends: string[] = [];
    const cleared: string[] = [];
    let token = "activity-A";
    let endResult: "sent" | "retryable" = "sent";
    const run = async () => {
      const replay = f.restart();
      return await reconcileLiveActivity({
        lines: [],
        activityToken: token,
        retiringToken: destination === "retiring" ? token : null,
        startToken: null,
        startedAt: new Date(0).toISOString(),
        nowMs: 1000,
        hasAlert: false,
        send: (event, target) =>
          replay.send(`live:${target}:${event}`, false, () => {
            sends.push(token);
            return Promise.resolve(endResult);
          }, token),
        claimStart: () => Promise.resolve(null),
        releaseStart: () => Promise.resolve(),
        recordStart: () => Promise.resolve(),
        recordAdoption: () => Promise.resolve(),
        recordEnd: () => {
          if (destination === "activity") cleared.push(token);
          return Promise.resolve();
        },
        clearRetiring: () => {
          cleared.push(token);
          return Promise.resolve();
        },
      });
    };
    await run(); // APNs success persisted, job completion was interrupted.
    assertEquals(f.read().status, "pending");
    await run(); // Same identity can safely reuse its persisted end.
    assertEquals(sends, ["activity-A"]);
    cleared.length = 0;
    token = "activity-B";
    endResult = "retryable";
    assertEquals((await run()).results, ["retryable"]);
    assertEquals(cleared, []);
    endResult = "sent";
    const result = await run();
    await f.restart().finish(result.results);
    assertEquals(sends, ["activity-A", "activity-B", "activity-B"]);
    assertEquals(cleared, ["activity-B"]);
    assertEquals(f.read().status, "complete");
  });
}

Deno.test("unscoped live outcomes cannot clear a new destination and alerts stay deduplicated", async () => {
  const f = fixture();
  await f.restart().send(
    "live:activity:end",
    false,
    () => Promise.resolve("sent"),
  );
  await f.restart().send("alert", true, () => Promise.resolve("sent"));
  const next = f.restart();
  let sends = 0;
  assertEquals(
    await next.send("live:activity:end", false, () => {
      sends++;
      return Promise.resolve("retryable");
    }, "replacement"),
    "retryable",
  );
  assertEquals(sends, 1);
  assertEquals(next.alertSent, true);
  await next.send("alert", true, () => {
    throw new Error("duplicate alert");
  });
});
