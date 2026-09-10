import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const originalToken = "a".repeat(64);
const replacementToken = "b".repeat(64);
let handler: (request: Request) => Response | Promise<Response>;
const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
Object.defineProperty(Deno, "serve", {
  configurable: true,
  value: (callback: typeof handler) => {
    handler = callback;
  },
});
try {
  await import("./index.ts");
} finally {
  Object.defineProperty(Deno, "serve", originalServe);
}

const key = await crypto.subtle.generateKey(
  { name: "ECDSA", namedCurve: "P-256" },
  true,
  ["sign", "verify"],
);
const keyBytes = new Uint8Array(
  await crypto.subtle.exportKey("pkcs8", key.privateKey),
);
const env = {
  SUPABASE_URL: "https://live-activity-test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-service-key",
  WEBHOOK_SECRET: "test-webhook-secret",
  APNS_KEY_ID: "test-key-id",
  APNS_TEAM_ID: "test-team-id",
  APNS_PRIVATE_KEY: `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...keyBytes))
  }\n-----END PRIVATE KEY-----`,
  APNS_TOPIC: "systems.edmundlim.LazyMansReminders",
};

async function exercise(input: {
  payload?: unknown;
  boardError?: boolean;
  activityToken?: string | null;
  uploadDuringStart?: boolean;
  rejectOldActivity?: boolean;
}) {
  const previousEnv = new Map(
    Object.keys(env).map((name) => [name, Deno.env.get(name)]),
  );
  for (const [name, value] of Object.entries(env)) Deno.env.set(name, value);
  const device = {
    user_id: userId,
    token: "c".repeat(64),
    environment: "production",
    push_to_start_token: "d".repeat(64),
    activity_push_token: input.activityToken === undefined
      ? originalToken
      : input.activityToken,
    activity_started_at: new Date(Date.now() - 8 * 60 * 60 * 1000)
      .toISOString(),
  };
  const uploadedAt = new Date().toISOString();
  const events: string[] = [];
  const patches: URL[] = [];
  const originalFetch = globalThis.fetch;
  const respond = (resource: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(
      resource instanceof Request ? resource.url : String(resource),
    );
    if (url.hostname === "api.push.apple.com") {
      const body = JSON.parse(String(init?.body));
      events.push(body.aps.event);
      if (body.aps.event === "start" && input.uploadDuringStart) {
        device.activity_push_token = replacementToken;
        device.activity_started_at = uploadedAt;
      }
      if (body.aps.event === "end" && input.rejectOldActivity) {
        return Response.json({ reason: "Unregistered" }, { status: 410 });
      }
      return new Response(null, { status: 200 });
    }
    if (url.pathname.endsWith("/device_tokens")) {
      if (init?.method === "PATCH") {
        patches.push(url);
        const filter = url.searchParams.get("activity_push_token");
        if (
          filter == null ||
          (filter === "is.null" && device.activity_push_token === null) ||
          filter === `eq.${device.activity_push_token}`
        ) Object.assign(device, JSON.parse(String(init.body)));
        return new Response(null, { status: 204 });
      }
      return Response.json([{ ...device }]);
    }
    if (url.pathname.endsWith("/reminders")) {
      return input.boardError
        ? Response.json({ message: "board temporarily unavailable" }, {
          status: 503,
        })
        : Response.json([{ text: "Milk" }]);
    }
    if (url.pathname.endsWith("/lock_screen_prefs")) {
      return Response.json({ max_lines: 6 });
    }
    throw new Error(`Unexpected request ${url}`);
  };
  globalThis.fetch = (resource, init) =>
    Promise.resolve(respond(resource, init));
  try {
    const response = await handler(
      new Request("https://function.test", {
        method: "POST",
        headers: { "x-webhook-secret": env.WEBHOOK_SECRET },
        body: JSON.stringify(
          input.payload ?? { type: "live_activity_refresh" },
        ),
      }),
    );
    return { response, events, device, patches, uploadedAt };
  } finally {
    globalThis.fetch = originalFetch;
    for (const [name, value] of previousEnv) {
      if (value == null) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
}

Deno.test("refresh does not end an activity when the board read fails", async () => {
  const result = await exercise({ boardError: true });
  assertEquals(result.response.status, 503);
  assertEquals(result.events, []);
});

Deno.test("reminder webhook does not end an activity when the board read fails", async () => {
  const result = await exercise({
    boardError: true,
    payload: {
      type: "UPDATE",
      table: "reminders",
      schema: "public",
      record: { user_id: userId },
    },
  });
  assertEquals(result.response.status, 503);
  assertEquals(result.events, []);
});

for (const activityToken of [originalToken, null]) {
  Deno.test(`start bookkeeping preserves a concurrent upload from ${activityToken === null ? "no activity" : "an old activity"}`, async () => {
    const result = await exercise({ activityToken, uploadDuringStart: true });
    assertEquals(result.response.status, 200);
    assertEquals(result.events.includes("start"), true);
    assertEquals(result.device.activity_push_token, replacementToken);
    assertEquals(
      Date.now() - Date.parse(result.device.activity_started_at) < 60_000,
      true,
    );
  });

  Deno.test(`start bookkeeping records an uncontested start from ${activityToken === null ? "no activity" : "an old activity"}`, async () => {
    const result = await exercise({ activityToken });
    assertEquals(result.response.status, 200);
    assertEquals(result.device.activity_push_token, null);
    assertEquals(
      Date.now() - Date.parse(result.device.activity_started_at) < 60_000,
      true,
    );
    assertEquals(
      result.patches.at(-1)?.searchParams.get("activity_push_token"),
      activityToken === null ? "is.null" : `eq.${activityToken}`,
    );
  });
}

for (const uploadDuringStart of [false, true]) {
  Deno.test(`recycle records the start after 410 while preserving ${uploadDuringStart ? "a replacement token" : "a cleared token"}`, async () => {
    const result = await exercise({
      rejectOldActivity: true,
      uploadDuringStart,
    });
    assertEquals(result.response.status, 200);
    assertEquals(result.events, ["start", "end"]);
    assertEquals(
      result.device.activity_push_token,
      uploadDuringStart ? replacementToken : null,
    );
    assertEquals(
      Date.now() - Date.parse(result.device.activity_started_at) < 60_000,
      true,
    );
  });
}
