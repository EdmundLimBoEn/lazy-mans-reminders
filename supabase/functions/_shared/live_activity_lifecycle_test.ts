import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { reconcileLiveActivity } from "./live_activity_lifecycle.ts";
import {
  type ApnsOutcome,
  classifyApnsResponse,
  deliverWithRetries,
} from "./push_helpers.ts";

const hour = 60 * 60 * 1000;
type Result = "sent" | "failed" | "retryable" | "invalid";

function phone() {
  const state = {
    activityToken: "old",
    retiringToken: null as string | null,
    startedAt: new Date(0).toISOString() as string | null,
  };
  const sent: string[] = [];
  let nowMs = 7 * hour;
  let lines = ["Milk"];
  let outcome: Result = "sent";
  let uploadDuringStart = false;
  let leaseExpiresAt = 0;
  const released: string[] = [];
  let queuedOutcomes: Result[] = [];
  return {
    state,
    sent,
    released,
    outcomes: (...values: Result[]) => {
      queuedOutcomes = values;
    },
    advance: (ms: number) => {
      nowMs += ms;
    },
    empty: () => {
      lines = [];
    },
    outcome: (value: Result) => {
      outcome = value;
    },
    uploadDuringStart: () => {
      uploadDuringStart = true;
    },
    run: (quiet = true) => {
      const previous = state.activityToken;
      return reconcileLiveActivity({
        ...state,
        startToken: "start",
        lines,
        nowMs,
        quiet,
        hasAlert: false,
        send: (event, destination) => {
          sent.push(`${event}:${destination}`);
          if (event === "start" && uploadDuringStart) {
            state.activityToken = "new";
          }
          const result = queuedOutcomes.shift() ?? outcome;
          if (result === "invalid") {
            if (destination === "activity") {
              state.activityToken = "";
              state.startedAt = null;
            }
            if (destination === "retiring") state.retiringToken = null;
          }
          return Promise.resolve(result);
        },
        claimStart: () => {
          if (nowMs < leaseExpiresAt) return Promise.resolve(null);
          leaseExpiresAt = nowMs + 2 * 60 * 1000;
          return Promise.resolve("lease");
        },
        releaseStart: (id) => {
          released.push(id);
          leaseExpiresAt = 0;
          return Promise.resolve();
        },
        recordStart: (replacing) => {
          leaseExpiresAt = 0;
          state.startedAt = new Date(nowMs).toISOString();
          if (replacing) state.retiringToken = previous;
          if (state.activityToken === previous) state.activityToken = "";
          return Promise.resolve();
        },
        recordEnd: () => {
          state.activityToken = "";
          return Promise.resolve();
        },
        recordAdoption: () => Promise.resolve(),
        clearRetiring: () => {
          state.retiringToken = null;
          return Promise.resolve();
        },
        activityToken: state.activityToken || null,
      });
    },
  };
}

Deno.test("delayed replacement delivery never ends the only visible banner", async () => {
  const device = phone();
  await device.run();
  assertEquals(device.sent, ["start:push-to-start"]);
  assertEquals(device.state.retiringToken, "old");
  device.advance(15 * 60 * 1000);
  await device.run();
  assertEquals(device.sent, ["start:push-to-start"]);
});

Deno.test("the next refresh retires the old banner only after a new token arrives", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "new";
  device.advance(15 * 60 * 1000);
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "update:activity",
  ]);
  assertEquals(device.state.activityToken, "new");
  assertEquals(device.state.retiringToken, null);
});

Deno.test("re-uploading the old token does not acknowledge a replacement", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "old";
  device.advance(15 * 60 * 1000);
  await device.run();
  assertEquals(device.sent, ["start:push-to-start"]);
  assertEquals(device.state.retiringToken, "old");
});

Deno.test("emptying the board during handoff ends the old banner", async () => {
  const device = phone();
  await device.run();
  device.empty();
  await device.run();
  assertEquals(device.sent, ["start:push-to-start", "end:retiring"]);
  assertEquals(device.state.retiringToken, null);
});

Deno.test("emptying a board ends both acknowledged banners", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "new";
  device.empty();
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "end:activity",
  ]);
});

Deno.test("a failed replacement leaves the old token and its clock intact", async () => {
  const device = phone();
  device.outcome("retryable");
  await device.run();
  assertEquals(device.state.activityToken, "old");
  assertEquals(device.state.startedAt, new Date(0).toISOString());
  assertEquals(device.state.retiringToken, null);
});

Deno.test("a failed retirement is retried without starting more banners", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "new";
  device.outcome("retryable");
  await device.run();
  assertEquals(device.state.retiringToken, "old");
  device.outcome("sent");
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "end:retiring",
    "update:activity",
  ]);
});

Deno.test("a token uploaded while the start request is in flight survives recording", async () => {
  const device = phone();
  device.uploadDuringStart();
  await device.run();
  assertEquals(device.state.activityToken, "new");
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "update:activity",
  ]);
});

Deno.test("a transient update failure does not start a duplicate banner", async () => {
  const device = phone();
  device.advance(-6 * hour);
  device.outcome("retryable");
  await device.run(false);
  assertEquals(device.sent, ["update:activity"]);
});

Deno.test("a quiet two-hour-old activity is refreshed while the app is suspended", async () => {
  const device = phone();
  device.advance(-5 * hour);
  await device.run();
  assertEquals(device.sent, ["update:activity"]);
});

Deno.test("an APNs configuration failure does not create another activity", async () => {
  const device = phone();
  device.advance(-5 * hour);
  device.outcome("failed");
  await device.run(false);
  assertEquals(device.sent, ["update:activity"]);
});

Deno.test("a two-hour-old invalid token is replaced without reopening the app", async () => {
  const device = phone();
  device.advance(-5 * hour);
  device.outcomes("invalid", "sent");
  await device.run();
  assertEquals(device.sent, ["update:activity", "start:push-to-start"]);
  assertEquals(device.state.startedAt, new Date(2 * hour).toISOString());
  device.advance(15 * 60 * 1000);
  await device.run();
  assertEquals(device.sent, ["update:activity", "start:push-to-start"]);
});

Deno.test("an expired retirement token does not delay clearing the current board", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "new";
  device.empty();
  device.outcomes("invalid", "sent");
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "end:activity",
  ]);
  assertEquals(device.state.retiringToken, null);
  assertEquals(device.state.activityToken, "");
});

Deno.test("failed early recovery retries next refresh instead of waiting seven hours", async () => {
  const device = phone();
  device.advance(-5 * hour);
  device.outcomes("invalid", "retryable");
  await device.run();
  assertEquals(device.state.startedAt, null);
  device.advance(15 * 60 * 1000);
  await device.run();
  assertEquals(device.sent, [
    "update:activity",
    "start:push-to-start",
    "start:push-to-start",
  ]);
});

Deno.test("an acknowledged overnight replacement is updated past the original eight-hour deadline", async () => {
  const device = phone();
  await device.run();
  device.state.activityToken = "replacement";
  device.advance(2 * hour);
  await device.run();
  device.advance(2 * hour);
  await device.run();
  assertEquals(device.sent, [
    "start:push-to-start",
    "end:retiring",
    "update:activity",
    "update:activity",
  ]);
  assertEquals(device.state.retiringToken, null);
  assertEquals(device.state.activityToken, "replacement");
});

Deno.test("an expired APNs destination reaches replacement recovery through the transport", async () => {
  const sent: string[] = [];
  await reconcileLiveActivity({
    lines: ["Saved board"],
    activityToken: "expired",
    startToken: "start",
    retiringToken: null,
    startedAt: new Date(0).toISOString(),
    nowMs: 2 * hour,
    quiet: true,
    hasAlert: false,
    send: (event, destination) => {
      sent.push(`${event}:${destination}`);
      return deliverWithRetries({
        headers: {},
        send: () =>
          Promise.resolve(classifyApnsResponse(
            destination === "activity" ? 410 : 200,
            '{"reason":"Unregistered"}',
          )),
        nextJwt: () => Promise.resolve("jwt"),
        onExpiredJwt: () => {},
        onPrune: () => Promise.resolve(),
        sleep: () => Promise.resolve(),
      });
    },
    claimStart: () => Promise.resolve("lease"),
    releaseStart: () => Promise.resolve(),
    recordStart: () => Promise.resolve(),
    recordEnd: () => Promise.resolve(),
    recordAdoption: () => Promise.resolve(),
    clearRetiring: () => Promise.resolve(),
  });
  assertEquals(sent, ["update:activity", "start:push-to-start"]);
});

for (const activityToken of [null, "old"]) {
  Deno.test(`overlapping ${activityToken ? "renewals" : "initial starts"} send only once`, async () => {
    let held: string | null = null;
    let starts = 0;
    let recordings = 0;
    let unblock!: () => void;
    const pending = new Promise<void>((resolve) => unblock = resolve);
    const run = () =>
      reconcileLiveActivity({
        lines: ["Milk"],
        activityToken,
        startToken: "start",
        retiringToken: null,
        startedAt: activityToken ? new Date(0).toISOString() : null,
        nowMs: 7 * hour,
        hasAlert: true,
        claimStart: () => {
          if (held) return Promise.resolve(null);
          held = "winner";
          return Promise.resolve(held);
        },
        send: async () => {
          starts++;
          await pending;
          return "sent";
        },
        recordStart: (_replacing, leaseId) => {
          assertEquals(leaseId, held);
          recordings++;
          return Promise.resolve();
        },
        releaseStart: () => {
          throw new Error("Successful starts must complete the lease");
        },
        recordEnd: () => Promise.resolve(),
        recordAdoption: () => Promise.resolve(),
        clearRetiring: () => Promise.resolve(),
      });
    const first = run();
    const second = run();
    unblock();
    const results = await Promise.all([first, second]);
    assertEquals(starts, 1);
    assertEquals(recordings, 1);
    assertEquals(results.map((r) => r.deliveredAlert), [true, false]);
  });
}

for (const activityToken of ["", "old"]) {
  Deno.test(`uncertain ${activityToken ? "renewals" : "initial starts"} retain the lease until expiry`, async () => {
    const device = phone();
    device.state.activityToken = activityToken;
    const startedAt = activityToken ? new Date(0).toISOString() : null;
    device.state.startedAt = startedAt;
    device.outcome("retryable");

    const first = await device.run();
    assertEquals(first.results, ["retryable"]);
    assertEquals(first.deliveredAlert, false);
    device.advance(2 * 60 * 1000 - 1);
    const second = await device.run();
    assertEquals(second.results, []);
    assertEquals(device.sent, ["start:push-to-start"]);
    assertEquals(device.released, []);
    assertEquals(device.state.activityToken, activityToken);
    assertEquals(device.state.startedAt, startedAt);
    assertEquals(device.state.retiringToken, null);

    device.advance(1);
    await device.run();
    assertEquals(device.sent, ["start:push-to-start", "start:push-to-start"]);
  });
}

Deno.test("a token acknowledging an uncertain initial start permits updates during the lease", async () => {
  const device = phone();
  device.state.activityToken = "";
  device.state.startedAt = null;
  device.outcome("retryable");
  await device.run();
  device.state.activityToken = "acknowledged";
  device.outcome("sent");
  await device.run();
  assertEquals(device.sent, ["start:push-to-start", "update:activity"]);
  assertEquals(device.released, []);
});

for (const rejection of ["failed", "invalid"] as const) {
  Deno.test(`${rejection} starts release only their own lease and can retry`, async () => {
    const released: string[] = [];
    let claimed = 0;
    const run = () =>
      reconcileLiveActivity({
        lines: ["Milk"],
        activityToken: null,
        startToken: "start",
        retiringToken: null,
        startedAt: null,
        nowMs: 0,
        hasAlert: false,
        claimStart: () => Promise.resolve(`lease-${++claimed}`),
        send: () => Promise.resolve(rejection),
        recordStart: () => {
          throw new Error("Failed starts must not be recorded");
        },
        releaseStart: (id) => {
          released.push(id);
          return Promise.resolve();
        },
        recordEnd: () => Promise.resolve(),
        recordAdoption: () => Promise.resolve(),
        clearRetiring: () => Promise.resolve(),
      });
    await run();
    await run();
    assertEquals(released, ["lease-1", "lease-2"]);
  });
}

Deno.test("a failed lease claim never sends to APNs", async () => {
  let sends = 0;
  let rejected = false;
  try {
    await reconcileLiveActivity({
      lines: ["Milk"],
      activityToken: null,
      startToken: "start",
      retiringToken: null,
      startedAt: null,
      nowMs: 0,
      hasAlert: false,
      claimStart: () => Promise.reject(new Error("database unavailable")),
      send: () => {
        sends++;
        return Promise.resolve("sent");
      },
      recordStart: () => Promise.resolve(),
      releaseStart: () => Promise.resolve(),
      recordEnd: () => Promise.resolve(),
      recordAdoption: () => Promise.resolve(),
      clearRetiring: () => Promise.resolve(),
    });
  } catch {
    rejected = true;
  }
  assertEquals(rejected, true);
  assertEquals(sends, 0);
});

for (const laterStatus of [200, 400, 410, 503]) {
  for (const activityToken of [null, "old"]) {
    Deno.test(`uncertain start stops before ${laterStatus} and retains ${activityToken ? "renewal" : "initial"} lease`, async () => {
      let held = false;
      let attempts = 0;
      let releases = 0;
      let recordings = 0;
      let prunes = 0;
      let sleeps = 0;
      const run = () =>
        reconcileLiveActivity({
          lines: ["Milk"],
          activityToken,
          startToken: "start",
          retiringToken: null,
          startedAt: activityToken ? new Date(0).toISOString() : null,
          nowMs: 7 * hour,
          hasAlert: true,
          claimStart: () => {
            if (held) return Promise.resolve(null);
            held = true;
            return Promise.resolve("lease");
          },
          send: (event) =>
            deliverWithRetries({
              headers: {},
              stopOnUncertainDelivery: event === "start",
              send: (): Promise<ApnsOutcome> =>
                Promise.resolve(
                  ++attempts === 1
                    ? { kind: "uncertain", status: 0, reason: "network" }
                    : classifyApnsResponse(laterStatus, "{}"),
                ),
              nextJwt: () => Promise.resolve("jwt"),
              onExpiredJwt: () => {},
              onPrune: () => {
                prunes++;
                return Promise.resolve();
              },
              sleep: () => {
                sleeps++;
                return Promise.resolve();
              },
            }),
          releaseStart: () => {
            releases++;
            held = false;
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
      assertEquals(await run(), {
        results: ["retryable"],
        deliveredAlert: false,
      });
      assertEquals(await run(), { results: [], deliveredAlert: false });
      assertEquals({ attempts, releases, recordings, prunes, sleeps, held }, {
        attempts: 1,
        releases: 0,
        recordings: 0,
        prunes: 0,
        sleeps: 0,
        held: true,
      });
    });
  }
}
