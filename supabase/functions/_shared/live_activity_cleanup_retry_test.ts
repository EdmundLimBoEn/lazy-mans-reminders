/// <reference lib="dom" />
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { DeviceRow } from "./device_delivery.ts";
import type { PushJob } from "./push_replay.ts";

Deno.test("push jobs retry invalid Live Activity token cleanup before caching outcomes", async (t) => {
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
  const invalidToken = "a".repeat(64);
  let device: DeviceRow;
  let job: PushJob;
  let column:
    | "activity_push_token"
    | "retiring_activity_push_token"
    | "push_to_start_token";
  let cleanupAttempts: number;
  let sends: { event: string; token: string }[];
  let claims: number;
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
      const token = url.pathname.split("/").pop()!;
      sends.push({ event: body.aps.event, token });
      return Promise.resolve(
        token === invalidToken
          ? Response.json({ reason: "Unregistered" }, { status: 410 })
          : new Response(null, { status: 200 }),
      );
    }
    assertEquals(url.hostname, "test.invalid");
    switch (url.pathname) {
      case "/rest/v1/rpc/claim_device_delivery":
        return reply(true);
      case "/rest/v1/rpc/claim_live_activity_start":
        claims++;
        // A replacement cannot be claimed until the stale registration clears.
        // Each invocation represents a job retry after any prior lease expires.
        return reply(
          body.p_expected_token === device.activity_push_token &&
            body.p_expected_started_at === device.activity_started_at,
        );
      case "/rest/v1/rpc/release_device_delivery":
      case "/rest/v1/rpc/release_live_activity_start":
        return reply(null);
      case "/rest/v1/rpc/complete_live_activity_start":
        device.activity_started_at = body.p_started_at;
        return reply(null);
      case "/rest/v1/reminder_push_jobs":
        if (init?.method === "PATCH") Object.assign(job, body);
        return reply(job);
      case "/rest/v1/device_tokens":
        if (init?.method === "PATCH") {
          assertEquals(body[column], null);
          assertEquals(url.searchParams.get(column), `eq.${invalidToken}`);
          assertEquals(url.searchParams.get("token"), `eq.${device.token}`);
          assertEquals(url.searchParams.get("user_id"), `eq.${device.user_id}`);
          if (++cleanupAttempts === 1) {
            return Promise.resolve(
              Response.json({ message: "offline" }, { status: 503 }),
            );
          }
          Object.assign(device, body);
          return Promise.resolve(new Response(null, { status: 204 }));
        }
        return reply(device);
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
  const invoke = () =>
    handler(
      new Request("https://function.invalid", {
        method: "POST",
        headers: { "x-webhook-secret": "test-secret" },
        body: JSON.stringify({ job_id: job.id }),
      }),
    );
  try {
    await import("../send-reminder-push/index.ts");
    for (
      const destination of [
        "activity_push_token",
        "retiring_activity_push_token",
        "push_to_start_token",
      ] as const
    ) {
      await t.step(destination, async () => {
        column = destination;
        device = {
          token: "c".repeat(64),
          user_id: "22222222-2222-4222-8222-222222222222",
          environment: "development",
          updated_at: new Date().toISOString(),
          push_to_start_token: "d".repeat(64),
          activity_push_token: column === "push_to_start_token"
            ? null
            : "b".repeat(64),
          activity_started_at: column === "push_to_start_token"
            ? null
            : new Date().toISOString(),
          retiring_activity_push_token: null,
          [column]: invalidToken,
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
        cleanupAttempts = 0;
        claims = 0;
        sends = [];
        const first = await invoke();
        assertEquals(first.status, 503);
        assertEquals(await first.json(), { sent: 0, failed: 0, retryable: 1 });
        assertEquals(job.status, "pending");
        assertEquals(job.outcomes, {});
        assertEquals(device[column], invalidToken);
        assertEquals(cleanupAttempts, 1);
        assertEquals(claims, column === "push_to_start_token" ? 1 : 0);

        const retry = await invoke();
        assertEquals(retry.status, 200);
        await retry.json();
        assertEquals(job.status, "complete");
        assertEquals(cleanupAttempts, 2);
        assertEquals(device[column], null);
        assertEquals(Object.values(job.outcomes).includes("invalid"), true);
        const event = column === "activity_push_token"
          ? "update"
          : column === "retiring_activity_push_token"
          ? "end"
          : "start";
        assertEquals(sends, [
          { event, token: invalidToken },
          { event, token: invalidToken },
          ...(column === "push_to_start_token" ? [] : [{
            event: column === "activity_push_token" ? "start" : "update",
            token: column === "activity_push_token"
              ? device.push_to_start_token!
              : device.activity_push_token!,
          }]),
        ]);

        const duplicate = await invoke();
        assertEquals(duplicate.status, 200);
        await duplicate.json();
        assertEquals(cleanupAttempts, 2);
        assertEquals(sends.length, column === "push_to_start_token" ? 2 : 3);
      });
    }
  } finally {
    globalThis.fetch = originalFetch;
    Deno.serve = originalServe;
    Deno.env.get = originalEnv;
  }
});
