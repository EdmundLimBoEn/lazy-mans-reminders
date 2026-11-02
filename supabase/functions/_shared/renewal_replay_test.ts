/// <reference lib="dom" />
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { DeviceRow } from "./device_delivery.ts";
import type { PushJob } from "./push_replay.ts";

Deno.test("renewal replay preserves the accepted transition and replacement registration", async (t) => {
  const originalEnv = Deno.env.get;
  const originalServe = Deno.serve;
  const originalFetch = globalThis.fetch;
  let handler!: (request: Request) => Promise<Response>;
  const key = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", key.privateKey),
  );
  const env: Record<string, string> = {
    WEBHOOK_SECRET: "test-secret",
    SUPABASE_URL: "https://test.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "test-key",
    APNS_KEY_ID: "test-key-id",
    APNS_TEAM_ID: "test-team",
    APNS_TOPIC: "test.topic",
    APNS_PRIVATE_KEY: `-----BEGIN PRIVATE KEY-----\n${
      btoa(String.fromCharCode(...der))
    }\n-----END PRIVATE KEY-----`,
  };
  const activityA = "a".repeat(64);
  const activityB = "b".repeat(64);
  let device: DeviceRow;
  let job: PushJob;
  let failRecording: boolean;
  let sends: { event: string; token: string }[];
  let completions: Record<string, unknown>[];
  Deno.env.get = (name) => env[name];
  Deno.serve = ((callback: typeof handler) => {
    handler = callback;
    return {};
  }) as typeof Deno.serve;
  globalThis.fetch = (input, init) => {
    const url = new URL(String(input));
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    const reply = (value: unknown) => Promise.resolve(Response.json(value));
    if (url.hostname === "api.sandbox.push.apple.com") {
      sends.push({
        event: body.aps.event,
        token: url.pathname.split("/").pop()!,
      });
      return Promise.resolve(new Response(null, { status: 200 }));
    }
    assertEquals(url.hostname, "test.invalid");
    switch (url.pathname) {
      case "/rest/v1/rpc/claim_device_delivery":
      case "/rest/v1/rpc/claim_live_activity_start":
        // Each retry below represents a new delivery after lease expiry.
        return reply(true);
      case "/rest/v1/rpc/release_device_delivery":
        return reply(null);
      case "/rest/v1/rpc/complete_live_activity_start":
        completions.push(body);
        if (failRecording) {
          return Promise.resolve(
            Response.json({ message: "offline" }, { status: 503 }),
          );
        }
        // Apply record_live_activity_start's compare-and-clear semantics.
        device.activity_started_at = body.p_started_at;
        if (body.p_replacing) {
          device.retiring_activity_push_token = body.p_previous_token;
        }
        if (device.activity_push_token === body.p_previous_token) {
          device.activity_push_token = null;
        }
        return reply(null);
      case "/rest/v1/reminder_push_jobs":
        if (init?.method === "PATCH") Object.assign(job, body);
        return reply(job);
      case "/rest/v1/device_tokens":
        if (init?.method === "PATCH") {
          Object.assign(device, body);
          return Promise.resolve(new Response(null, { status: 204 }));
        }
        return reply(url.searchParams.has("or") ? [device] : device);
      case "/rest/v1/reminders":
        return reply([{
          id: "reminder",
          user_id: device.user_id,
          text: "Milk",
        }]);
      case "/rest/v1/lock_screen_prefs":
        return reply({ max_lines: 5 });
      default:
        throw new Error(`Unexpected test request: ${url.pathname}`);
    }
  };
  const invoke = (payload: unknown) =>
    handler(
      new Request("https://function.invalid", {
        method: "POST",
        headers: { "x-webhook-secret": "test-secret" },
        body: JSON.stringify(payload),
      }),
    );
  try {
    await import("../send-reminder-push/index.ts");
    for (const scenario of ["registered", "pending", "legacy"] as const) {
      await t.step(
        `replacement registration: ${scenario}`,
        async () => {
          const replacementRegistered = scenario !== "pending";
          device = {
            token: "c".repeat(64),
            user_id: "22222222-2222-4222-8222-222222222222",
            environment: "development",
            updated_at: new Date().toISOString(),
            push_to_start_token: "d".repeat(64),
            activity_push_token: activityA,
            activity_started_at: new Date(Date.now() - 8 * 60 * 60 * 1000)
              .toISOString(),
            retiring_activity_push_token: null,
          };
          job = {
            id: "11111111-1111-4111-8111-111111111111",
            user_id: device.user_id,
            device_token: device.token,
            payload: { type: "live_activity_refresh" },
            status: "pending",
            outcomes: {},
            alert_sent: false,
          };
          sends = [];
          completions = [];
          failRecording = true;
          const first = await invoke({ job_id: job.id });
          assertEquals(first.status, 503);
          await first.json();
          assertEquals(job.status, "pending");
          assertEquals(completions.length, 1);
          const acceptedStart = completions[0].p_started_at;
          if (replacementRegistered) device.activity_push_token = activityB;
          if (scenario === "legacy") {
            for (const key of Object.keys(job.outcomes)) {
              job.outcomes[key] = "sent";
            }
          }
          // Registration without a timestamp preserves A's old age, so retry renews.
          failRecording = false;
          await new Promise((resolve) => setTimeout(resolve, 5));
          const retry = await invoke({ job_id: job.id });
          assertEquals(retry.status, 200);
          await retry.json();
          assertEquals(job.status, "complete");
          assertEquals(sends, [{
            event: "start",
            token: device.push_to_start_token,
          }]);
          if (scenario === "legacy") {
            assertEquals(device.activity_push_token, activityB);
            assertEquals(device.retiring_activity_push_token, null);
            assertEquals(completions.length, 1);
            return;
          }
          assertEquals(
            device.activity_push_token,
            replacementRegistered ? activityB : null,
          );
          assertEquals(device.retiring_activity_push_token, activityA);
          assertEquals(device.activity_started_at, acceptedStart);
          assertEquals(completions[1].p_previous_token, activityA);
          assertEquals(completions[1].p_replacing, true);

          // Once B is registered, the next quiet refresh retires A and updates B.
          device.activity_push_token = activityB;
          const refresh = await invoke({ type: "live_activity_refresh" });
          assertEquals(refresh.status, 200);
          await refresh.json();
          assertEquals(sends.slice(1), [
            { event: "end", token: activityA },
            { event: "update", token: activityB },
          ]);
          assertEquals(device.activity_push_token, activityB);
        },
      );
    }
  } finally {
    globalThis.fetch = originalFetch;
    Deno.serve = originalServe;
    Deno.env.get = originalEnv;
  }
});
