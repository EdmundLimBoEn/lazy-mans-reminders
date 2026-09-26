import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { reconcileLiveActivity } from "./live_activity_lifecycle.ts";

const hour = 60 * 60 * 1000;
type Result = "sent" | "failed" | "retryable";

function phone() {
  const state = {
    activityToken: "old",
    retiringToken: null as string | null,
    startedAt: new Date(0).toISOString(),
  };
  const sent: string[] = [];
  let nowMs = 7 * hour;
  let lines = ["Milk"];
  let outcome: Result = "sent";
  let uploadDuringStart = false;
  return {
    state,
    sent,
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
          return Promise.resolve(outcome);
        },
        recordStart: (replacing) => {
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
  assertEquals(device.sent, ["start:push-to-start", "end:retiring"]);
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
  ]);
});

Deno.test("a token uploaded while the start request is in flight survives recording", async () => {
  const device = phone();
  device.uploadDuringStart();
  await device.run();
  assertEquals(device.state.activityToken, "new");
  await device.run();
  assertEquals(device.sent, ["start:push-to-start", "end:retiring"]);
});

Deno.test("a transient update failure does not start a duplicate banner", async () => {
  const device = phone();
  device.advance(-6 * hour);
  device.outcome("retryable");
  await device.run(false);
  assertEquals(device.sent, ["update:activity"]);
});
