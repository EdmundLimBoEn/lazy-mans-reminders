import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  deliverDevices,
  DELIVERY_SEND_WINDOW_MS,
  type DeviceRow,
} from "./device_delivery.ts";
import { reconcileLiveActivity } from "./live_activity_lifecycle.ts";

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function fixture() {
  const devices: DeviceRow[] = ["a", "b"].map((token) => ({
    token,
    user_id: "owner",
    environment: "production",
    updated_at: new Date(0).toISOString(),
    push_to_start_token: "start",
    activity_push_token: "activity",
    activity_started_at: new Date(0).toISOString(),
    retiring_activity_push_token: null,
  }));
  const state = {
    text: "Old",
    empty: false,
    readError: false,
    prefsError: false,
    reads: 0,
    now: 0,
  };
  const slots = new Map<string, unknown>();
  const supabase = {
    rpc(name: string, args: Record<string, unknown>) {
      const token = args.p_device_token as string;
      if (name === "claim_device_delivery") {
        if (slots.has(token)) {
          return Promise.resolve({ data: false, error: null });
        }
        slots.set(token, args.p_lease_id);
      } else if (name === "release_device_delivery") {
        if (slots.get(token) === args.p_lease_id) slots.delete(token);
      } else throw new Error("Unexpected RPC");
      return Promise.resolve({ data: true, error: null });
    },
    from(table: string) {
      const filters: Record<string, unknown> = {};
      const result = () => {
        if (table === "device_tokens") {
          return {
            data: devices.find((d) =>
              d.token === filters.token && d.user_id === filters.user_id
            ),
            error: null,
          };
        }
        if (table === "lock_screen_prefs") {
          return {
            data: state.prefsError ? null : { max_lines: 6 },
            error: state.prefsError ? "unavailable" : null,
          };
        }
        state.reads++;
        return {
          data: state.empty
            ? []
            : [{ id: "reminder", user_id: "owner", text: state.text }],
          error: state.readError ? "unavailable" : null,
        };
      };
      const query = {
        select: () => query,
        eq: (key: string, value: unknown) => {
          filters[key] = value;
          return query;
        },
        order: () => query,
        maybeSingle: () => Promise.resolve(result()),
        then: (resolve: (value: unknown) => unknown) =>
          Promise.resolve(result()).then(resolve),
      };
      return query;
    },
  };
  return { devices, state, slots, supabase };
}

Deno.test("older invocation blocked on device 1 reloads new board and registration for device 2", async () => {
  const f = fixture();
  const entered = deferred();
  const resume = deferred();
  const sent: string[] = [];
  const older = deliverDevices({
    ...f,
    devices: f.devices.map((device) => ({ ...device })),
    deliver: async (device, content) => {
      if (device.token === "a") {
        entered.resolve();
        await resume.promise;
      }
      sent.push(
        `${device.token}:${device.activity_push_token}:${content.lines.join()}`,
      );
      return ["sent"];
    },
  });
  await entered.promise;
  f.state.text = "New";
  f.devices[1].activity_push_token = "replacement";
  await deliverDevices({
    ...f,
    devices: [f.devices[1]],
    deliver: (device, content) => {
      sent.push(
        `${device.token}:${device.activity_push_token}:${content.lines.join()}`,
      );
      return Promise.resolve(["sent"]);
    },
  });
  resume.resolve();
  await older;
  assertEquals(sent, [
    "b:replacement:New",
    "a:activity:Old",
    "b:replacement:New",
  ]);
  assertEquals(f.slots.size, 0);
});

for (const event of ["start", "update", "end"] as const) {
  Deno.test(`${event} holds the shared slot through transport and bookkeeping`, async () => {
    const f = fixture();
    const device = f.devices[0];
    if (event === "start") {
      device.activity_push_token = null;
      device.activity_started_at = null;
    }
    if (event === "end") f.state.empty = true;
    const entered = deferred();
    const resume = deferred();
    const sent: string[] = [];
    const first = deliverDevices({
      ...f,
      devices: [device],
      deliver: async (current, content, assertCurrent) => {
        const result = await reconcileLiveActivity({
          lines: content.lines,
          activityToken: current.activity_push_token,
          startToken: current.push_to_start_token,
          retiringToken: null,
          startedAt: current.activity_started_at,
          nowMs: 1000,
          hasAlert: false,
          send: async (actual) => {
            assertCurrent();
            sent.push(actual);
            entered.resolve();
            await resume.promise;
            return "sent";
          },
          claimStart: () => Promise.resolve("start-lease"),
          releaseStart: () => Promise.resolve(),
          recordStart: () => {
            assertEquals(f.slots.has(device.token), true);
            return Promise.resolve();
          },
          recordEnd: () => {
            assertEquals(f.slots.has(device.token), true);
            return Promise.resolve();
          },
          recordAdoption: () => Promise.resolve(),
          clearRetiring: () => Promise.resolve(),
        });
        return result.results;
      },
    });
    await entered.promise;
    f.state.text = "Edited while sending";
    const blocked = await deliverDevices({
      ...f,
      devices: [device],
      deliver: () => {
        throw new Error("Must not deliver concurrently");
      },
    });
    assertEquals(blocked, ["retryable"]);
    assertEquals(f.state.reads, 1); // No stale snapshot is loaded by the losing invocation.
    resume.resolve();
    assertEquals(await first, ["sent"]);
    assertEquals(sent, [event]);
    assertEquals(f.slots.size, 0);
    await deliverDevices({
      ...f,
      devices: [device],
      deliver: (_device, content) => {
        assertEquals(
          content.lines,
          event === "end" ? [] : ["Edited while sending"],
        );
        return Promise.resolve(["sent"]);
      },
    });
  });
}

Deno.test("a completed reminder suppresses a delayed alert after acquiring the slot", async () => {
  const f = fixture();
  f.state.empty = true;
  await deliverDevices({
    ...f,
    alertCandidate: { id: "reminder", user_id: "owner", text: "Old" },
    deliver: (_device, content) => {
      assertEquals(content, { lines: [], alertRecord: undefined });
      return Promise.resolve([]);
    },
  });
});

Deno.test("board read and delivery failures release the slot and remain retryable", async () => {
  for (const readError of [true, false]) {
    const f = fixture();
    f.state.readError = readError;
    const result = await deliverDevices({
      ...f,
      devices: [f.devices[0]],
      deliver: () => {
        throw new Error("transport failed");
      },
    });
    assertEquals(result, ["retryable"]);
    assertEquals(f.slots.size, 0);
  }
});

Deno.test("preference read failures preserve activity content and release the slot for retry", async () => {
  const f = fixture();
  f.state.prefsError = true;
  let deliveries = 0;
  const input = {
    ...f,
    devices: [f.devices[0]],
    deliver: () => {
      deliveries++;
      return Promise.resolve(["sent" as const]);
    },
  };
  assertEquals(await deliverDevices(input), ["retryable"]);
  assertEquals(deliveries, 0);
  assertEquals(f.slots.size, 0);

  f.state.prefsError = false;
  assertEquals(await deliverDevices(input), ["sent"]);
  assertEquals(deliveries, 1);
  assertEquals(f.slots.size, 0);
});

Deno.test("expired workers cannot begin another send or retry with an old snapshot", async () => {
  const f = fixture();
  const result = await deliverDevices({
    ...f,
    devices: [f.devices[0]],
    now: () => f.state.now,
    deliver: (_device, _content, assertCurrent) => {
      assertCurrent();
      f.state.now += DELIVERY_SEND_WINDOW_MS;
      assertThrows(assertCurrent, Error, "expired");
      assertCurrent();
      return Promise.resolve(["sent"]);
    },
  });
  assertEquals(result, ["retryable"]);
  assertEquals(f.slots.size, 0);
});

Deno.test("a device removed or reassigned before reload receives no push", async () => {
  const f = fixture();
  const observed = { ...f.devices[0] };
  f.devices[0].user_id = "another-owner";
  assertEquals(
    await deliverDevices({
      ...f,
      devices: [observed],
      deliver: () => {
        throw new Error("Must not send");
      },
    }),
    [],
  );
  assertEquals(f.state.reads, 0);
  assertEquals(f.slots.size, 0);
});

for (
  const failure of [
    "claim",
    "recordStart",
    "recordAdoption",
    "release",
    "retiring",
  ] as const
) {
  for (const expired of [false, true]) {
    Deno.test(`${failure} failure preserves alert delivery with expired slot=${expired}`, async () => {
      const f = fixture();
      const device = f.devices[0];
      device.activity_push_token =
        failure === "recordAdoption" || failure === "retiring"
          ? "activity"
          : null;
      device.activity_started_at = null;
      const sends: string[] = [];
      const fail = () => {
        if (expired) f.state.now += DELIVERY_SEND_WINDOW_MS;
        return Promise.reject(new Error("bookkeeping unavailable"));
      };
      const result = await deliverDevices({
        ...f,
        devices: [device],
        now: () => f.state.now,
        alertCandidate: { id: "reminder", user_id: "owner", text: "Old" },
        deliver: async (current, content, assertCurrent) => {
          const live = await reconcileLiveActivity({
            lines: content.lines,
            activityToken: current.activity_push_token,
            startToken: current.push_to_start_token,
            retiringToken: failure === "retiring" ? "old" : null,
            startedAt: null,
            nowMs: 1000,
            hasAlert: Boolean(content.alertRecord),
            send: (event) => {
              assertCurrent();
              sends.push(event);
              return Promise.resolve(failure === "release" ? "failed" : "sent");
            },
            claimStart: failure === "claim"
              ? fail
              : () => Promise.resolve("lease"),
            releaseStart: failure === "release"
              ? fail
              : () => Promise.resolve(),
            recordStart: failure === "recordStart"
              ? fail
              : () => Promise.resolve(),
            recordAdoption: failure === "recordAdoption"
              ? fail
              : () => Promise.resolve(),
            recordEnd: () => Promise.resolve(),
            clearRetiring: failure === "retiring"
              ? fail
              : () => Promise.resolve(),
          });
          if (content.alertRecord && !live.deliveredAlert) {
            assertCurrent();
            sends.push("alert");
            live.results.push("sent");
          }
          return live.results;
        },
      });
      const delivered = failure === "recordStart" ||
        failure === "recordAdoption";
      const liveSends = failure === "claim" ? [] : [
        failure === "retiring"
          ? "end"
          : failure === "recordAdoption"
          ? "update"
          : "start",
      ];
      assertEquals(sends, [
        ...liveSends,
        ...(!delivered && !expired ? ["alert"] : []),
      ]);
      assertEquals(
        result,
        expired && !delivered ? ["retryable"] : [
          ...(liveSends.length
            ? [failure === "release" ? "failed" : "sent"]
            : []),
          "retryable",
          ...(!delivered ? ["sent"] : []),
        ],
      );
      assertEquals(f.slots.size, 0);
    });
  }
}
