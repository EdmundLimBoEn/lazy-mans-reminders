/// <reference lib="dom" />
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { DeviceRow } from "./device_delivery.ts";
import type { PushJob } from "./push_replay.ts";

Deno.test("alert rejection retries failed pruning and completes after a cascade", async (t) => {
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
  const jobId = "11111111-1111-4111-8111-111111111111";
  const userId = "22222222-2222-4222-8222-222222222222";
  const deviceToken = "a".repeat(64);
  const record = { id: jobId, user_id: userId, text: "Milk" };
  const registered = "2026-10-28T00:00:00.000Z";
  const refreshed = "2026-10-28T00:00:00.001Z";
  const invalidated = "2026-10-28T00:00:01.000Z";
  let device: DeviceRow | null;
  let job: PushJob | null;
  let deleteFails = false;
  let refreshOnSend = false;
  let sends = 0;
  let jobWrites = 0;

  const reset = (startToken: string | null = null) => {
    device = {
      token: deviceToken,
      user_id: userId,
      environment: "development",
      updated_at: registered,
      push_to_start_token: startToken,
      activity_push_token: null,
      activity_started_at: null,
      retiring_activity_push_token: null,
    };
    job = {
      id: jobId,
      user_id: userId,
      device_token: deviceToken,
      payload: { schema: "public", table: "reminders", type: "INSERT", record },
      status: "pending",
      outcomes: {},
      alert_sent: false,
    };
    deleteFails = false;
    refreshOnSend = false;
    sends = 0;
    jobWrites = 0;
  };
  const read = () => ({ device, job });

  Deno.env.get = (name) => env[name];
  Deno.serve = ((callback: typeof handler) => {
    handler = callback;
    return {};
  }) as typeof Deno.serve;
  const fetchResponse = (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.hostname === "api.sandbox.push.apple.com") {
      assertEquals(url.pathname, `/3/device/${deviceToken}`);
      sends++;
      if (refreshOnSend && device) device.updated_at = refreshed;
      return Response.json({
        reason: "Unregistered",
        timestamp: Date.parse(invalidated),
      }, { status: 410 });
    }
    assertEquals(url.hostname, "test.invalid");
    switch (url.pathname) {
      case "/rest/v1/rpc/claim_device_delivery":
        return Response.json(true);
      case "/rest/v1/rpc/claim_live_activity_start":
        return Response.json(false);
      case "/rest/v1/rpc/release_device_delivery":
        return device
          ? Response.json(null)
          : Response.json({ message: "test release failure" }, { status: 503 });
      case "/rest/v1/reminders":
        return Response.json([record]);
      case "/rest/v1/lock_screen_prefs":
        return Response.json([{ max_lines: 5 }]);
      case "/rest/v1/reminder_push_jobs":
        if (init?.method === "PATCH") {
          jobWrites++;
          if (job?.status === "pending") {
            Object.assign(job, JSON.parse(String(init.body)));
            return Response.json([{ id: job.id }]);
          }
          return Response.json([]);
        }
        return Response.json(job ? [job] : []);
      case "/rest/v1/device_tokens": {
        if (init?.method !== "DELETE") {
          return Response.json(device ? [device] : []);
        }
        if (deleteFails) {
          return Response.json({ message: "test delete failure" }, {
            status: 503,
          });
        }
        const revision = url.searchParams.getAll("updated_at");
        assertEquals(revision, [`eq.${registered}`, `lte.${invalidated}`]);
        assertEquals(url.searchParams.get("token"), `eq.${deviceToken}`);
        assertEquals(url.searchParams.get("user_id"), `eq.${userId}`);
        const matches = device?.updated_at === registered;
        if (matches) {
          device = null;
          job = null; // The device foreign key cascades to push jobs.
        }
        return url.searchParams.has("select")
          ? Response.json(matches ? [{ token: deviceToken }] : [])
          : new Response(null, { status: 204 });
      }
      default:
        throw new Error(`Unexpected test request: ${url.pathname}`);
    }
  };
  globalThis.fetch = (input, init) =>
    Promise.resolve(fetchResponse(input, init));

  const invoke = async () => {
    const response = await handler(
      new Request("https://function.invalid", {
        method: "POST",
        headers: { "x-webhook-secret": "test-secret" },
        body: JSON.stringify({ job_id: jobId }),
      }),
    );
    return { status: response.status, body: await response.json() };
  };

  try {
    await import("../send-reminder-push/index.ts");
    await t.step(
      "delete failure leaves the job pending for a successful retry",
      async () => {
        reset();
        deleteFails = true;
        assertEquals(await invoke(), {
          status: 503,
          body: { sent: 0, failed: 0, retryable: 1 },
        });
        assertEquals(read().device?.updated_at, registered);
        assertEquals(read().job?.status, "pending");
        assertEquals(read().job?.outcomes, {});

        deleteFails = false;
        assertEquals(await invoke(), {
          status: 200,
          body: { sent: 0, failed: 1, retryable: 0 },
        });
        assertEquals(read(), { device: null, job: null });
        assertEquals(sends, 2);
        assertEquals(jobWrites, 0);
        assertEquals(await invoke(), {
          status: 200,
          body: { sent: 0, failed: 0, retryable: 0 },
        });
        assertEquals(sends, 2);
      },
    );

    await t.step(
      "confirmed cascade ends retryable work for that device",
      async () => {
        reset("b".repeat(64));
        assertEquals(await invoke(), {
          status: 200,
          body: { sent: 0, failed: 1, retryable: 0 },
        });
        assertEquals(read(), { device: null, job: null });
        assertEquals(sends, 1);
        assertEquals(jobWrites, 0);
      },
    );

    await t.step(
      "a refreshed registration survives and its job completes normally",
      async () => {
        reset();
        refreshOnSend = true;
        assertEquals(await invoke(), {
          status: 200,
          body: { sent: 0, failed: 1, retryable: 0 },
        });
        assertEquals(read().device?.updated_at, refreshed);
        assertEquals(read().job?.status, "complete");
        assertEquals(read().job?.outcomes, { alert: "invalid" });
        assertEquals(sends, 1);
      },
    );
  } finally {
    globalThis.fetch = originalFetch;
    Deno.serve = originalServe;
    Deno.env.get = originalEnv;
  }
});
