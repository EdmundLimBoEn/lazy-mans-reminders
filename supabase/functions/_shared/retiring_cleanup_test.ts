/// <reference lib="dom" />
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
function stub<T, K extends keyof T>(object: T, key: K, replacement: T[K]) {
  const original = object[key];
  object[key] = replacement;
  return {
    restore: () => {
      object[key] = original;
    },
  };
}

Deno.test("successful retiring push clears only the token read before sending", async () => {
  const oldToken = "a".repeat(64);
  const replacement = "b".repeat(64);
  let storedToken: string | null = oldToken;
  let replaceDuringSend = false;
  let cleanupCalls = 0;
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
  const envStub = stub(Deno.env, "get", (name) => env[name]);
  const serveStub = stub(
    Deno,
    "serve",
    ((callback: typeof handler) => {
      handler = callback;
      return {};
    }) as typeof Deno.serve,
  );
  const fetchStub = stub(globalThis, "fetch", (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "api.sandbox.push.apple.com") {
      assertEquals(url.pathname, `/3/device/${oldToken}`);
      if (replaceDuringSend) storedToken = replacement;
      return Promise.resolve(new Response(null, { status: 200 }));
    }
    assertEquals(url.hostname, "test.invalid");
    if (url.pathname === "/rest/v1/rpc/claim_device_delivery") {
      return Promise.resolve(Response.json(true));
    }
    if (url.pathname === "/rest/v1/rpc/release_device_delivery") {
      return Promise.resolve(Response.json(null));
    }
    if (url.pathname === "/rest/v1/device_tokens" && init?.method === "PATCH") {
      const patch = JSON.parse(String(init.body));
      if ("retiring_activity_push_token" in patch) {
        cleanupCalls++;
        const expected = url.searchParams.get("retiring_activity_push_token");
        if (expected === null || expected === `eq.${storedToken}`) {
          storedToken = null;
        }
      }
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    const data = url.pathname === "/rest/v1/device_tokens"
      ? [{
        token: "c".repeat(64),
        user_id: "22222222-2222-4222-8222-222222222222",
        environment: "development",
        push_to_start_token: null,
        activity_push_token: null,
        activity_started_at: null,
        retiring_activity_push_token: storedToken,
      }]
      : url.pathname === "/rest/v1/reminders"
      ? []
      : { max_lines: 5 };
    return Promise.resolve(Response.json(data));
  });
  try {
    await import("../send-reminder-push/index.ts");
    for (const replace of [false, true]) {
      storedToken = oldToken;
      replaceDuringSend = replace;
      const response = await handler(
        new Request("https://function.invalid", {
          method: "POST",
          headers: { "x-webhook-secret": "test-secret" },
          body: JSON.stringify({ type: "live_activity_refresh" }),
        }),
      );
      assertEquals(response.status, 200);
      assertEquals(await response.json(), { sent: 1, failed: 0, retryable: 0 });
      assertEquals(storedToken, replace ? replacement : null);
    }
    assertEquals(cleanupCalls, 2);
  } finally {
    fetchStub.restore();
    serveStub.restore();
    envStub.restore();
  }
});
