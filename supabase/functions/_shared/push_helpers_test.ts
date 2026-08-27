import {
  assertEquals,
  assertFalse,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  APNS_TOKEN_PATTERN,
  apnsCollapseId,
  apnsExpirationUnix,
  apnsHostForEnvironment,
  APNS_EXPIRATION_TTL_SECONDS,
  base64url,
  buildApnsHeaders,
  buildApnsPayload,
  classifyApnsResponse,
  classifyWebhookPayload,
  delayMsForAttempt,
  parseApnsReason,
  UUID_PATTERN,
  webhookStatusForResults,
} from "./push_helpers.ts";

Deno.test("base64url encodes without padding and uses URL-safe alphabet", () => {
  // "??>" base64 is "Pz4=" — should strip padding and keep URL-safe chars.
  assertEquals(base64url("?>"), "Pz4");
  assertEquals(base64url(new Uint8Array([0xff, 0xef])), "_-8");
});

Deno.test("UUID_PATTERN accepts common UUID versions used by Postgres", () => {
  assertMatch("11111111-1111-4111-8111-111111111111", UUID_PATTERN);
  assertFalse(UUID_PATTERN.test("not-a-uuid"));
  assertFalse(UUID_PATTERN.test("11111111-1111-9111-8111-111111111111")); // version nibble
});

Deno.test("APNS_TOKEN_PATTERN requires 64 hex chars", () => {
  const token = "a".repeat(64);
  assertMatch(token, APNS_TOKEN_PATTERN);
  assertFalse(APNS_TOKEN_PATTERN.test("a".repeat(63)));
  assertFalse(APNS_TOKEN_PATTERN.test("g".repeat(64)));
});

Deno.test("classifyWebhookPayload ignores non-insert reminder events", () => {
  assertEquals(
    classifyWebhookPayload({
      type: "UPDATE",
      table: "reminders",
      schema: "public",
      record: {
        id: "11111111-1111-4111-8111-111111111111",
        user_id: "22222222-2222-4222-8222-222222222222",
        text: "x",
      },
    }),
    { ok: true, kind: "ignore" },
  );
});

Deno.test("classifyWebhookPayload accepts a valid INSERT", () => {
  assertEquals(
    classifyWebhookPayload({
      type: "INSERT",
      table: "reminders",
      schema: "public",
      record: {
        id: "11111111-1111-4111-8111-111111111111",
        user_id: "22222222-2222-4222-8222-222222222222",
        text: "Book dentist",
      },
    }),
    { ok: true, kind: "process" },
  );
});

Deno.test("classifyWebhookPayload rejects empty or oversized text", () => {
  const base = {
    type: "INSERT" as const,
    table: "reminders",
    schema: "public",
    record: {
      id: "11111111-1111-4111-8111-111111111111",
      user_id: "22222222-2222-4222-8222-222222222222",
      text: "",
    },
  };
  assertEquals(classifyWebhookPayload(base), {
    ok: false,
    status: 400,
    message: "Invalid webhook payload",
  });
  assertEquals(
    classifyWebhookPayload({
      ...base,
      record: { ...base.record, text: "x".repeat(501) },
    }),
    { ok: false, status: 400, message: "Invalid webhook payload" },
  );
});

Deno.test("apnsHostForEnvironment picks sandbox vs production", () => {
  assertEquals(
    apnsHostForEnvironment("development"),
    "https://api.sandbox.push.apple.com",
  );
  assertEquals(
    apnsHostForEnvironment("production"),
    "https://api.push.apple.com",
  );
  assertEquals(
    apnsHostForEnvironment("unexpected"),
    "https://api.push.apple.com",
  );
});

Deno.test("apnsExpirationUnix is a future UNIX timestamp 24h out", () => {
  const now = Date.parse("2026-08-27T01:00:00Z");
  assertEquals(apnsExpirationUnix(now), now / 1000 + APNS_EXPIRATION_TTL_SECONDS);
});

Deno.test("apnsCollapseId is the reminder id (fits APNs 64-byte limit)", () => {
  const id = "11111111-1111-4111-8111-111111111111";
  assertEquals(apnsCollapseId(id), id);
  assertEquals(apnsCollapseId(id).length <= 64, true);
});

Deno.test("delayMsForAttempt backs off then clamps", () => {
  assertEquals(delayMsForAttempt(0), 200);
  assertEquals(delayMsForAttempt(1), 400);
  assertEquals(delayMsForAttempt(2), 400);
});

Deno.test("parseApnsReason reads JSON reason and ignores junk", () => {
  assertEquals(parseApnsReason('{"reason":"BadDeviceToken"}'), "BadDeviceToken");
  assertEquals(parseApnsReason("not-json"), "");
  assertEquals(parseApnsReason("{}"), "");
});

Deno.test("classifyApnsResponse sent / prune / retry / jwt / permanent", () => {
  assertEquals(classifyApnsResponse(200, ""), { kind: "sent" });
  assertEquals(classifyApnsResponse(410, '{"reason":"Unregistered"}'), {
    kind: "prune",
    status: 410,
    reason: "Unregistered",
  });
  assertEquals(classifyApnsResponse(400, '{"reason":"BadDeviceToken"}'), {
    kind: "prune",
    status: 400,
    reason: "BadDeviceToken",
  });
  assertEquals(classifyApnsResponse(400, '{"reason":"DeviceTokenNotForTopic"}'), {
    kind: "prune",
    status: 400,
    reason: "DeviceTokenNotForTopic",
  });
  assertEquals(classifyApnsResponse(403, '{"reason":"ExpiredProviderToken"}'), {
    kind: "expired_jwt",
    status: 403,
    reason: "ExpiredProviderToken",
  });
  assertEquals(classifyApnsResponse(429, '{"reason":"TooManyRequests"}'), {
    kind: "retryable",
    status: 429,
    reason: "TooManyRequests",
  });
  assertEquals(classifyApnsResponse(503, '{"reason":"Shutdown"}'), {
    kind: "retryable",
    status: 503,
    reason: "Shutdown",
  });
  assertEquals(classifyApnsResponse(400, '{"reason":"BadCollapseId"}'), {
    kind: "permanent",
    status: 400,
    reason: "BadCollapseId",
  });
});

Deno.test("buildApnsHeaders sets expiration, collapse id, and alert type", () => {
  const headers = buildApnsHeaders({
    jwt: "token",
    topic: "systems.edmundlim.LazyMansReminders",
    collapseId: "11111111-1111-4111-8111-111111111111",
    expirationUnix: 1_775_000_000,
  });
  assertEquals(headers.authorization, "bearer token");
  assertEquals(headers["apns-topic"], "systems.edmundlim.LazyMansReminders");
  assertEquals(headers["apns-push-type"], "alert");
  assertEquals(headers["apns-priority"], "10");
  assertEquals(headers["apns-expiration"], "1775000000");
  assertEquals(
    headers["apns-collapse-id"],
    "11111111-1111-4111-8111-111111111111",
  );
});

Deno.test("buildApnsPayload is body-only with reminder_id for the client", () => {
  const body = JSON.parse(buildApnsPayload({
    id: "11111111-1111-4111-8111-111111111111",
    user_id: "22222222-2222-4222-8222-222222222222",
    text: "Book dentist",
  }));
  assertEquals(body.aps.alert, { body: "Book dentist" });
  assertEquals(body.aps.sound, "default");
  assertEquals(body.aps["content-available"], 1);
  assertEquals(body.reminder_id, "11111111-1111-4111-8111-111111111111");
  assertEquals(body.aps.alert.title, undefined);
});

Deno.test("webhookStatusForResults is 503 only while APNs might still succeed", () => {
  assertEquals(webhookStatusForResults(0), 200);
  assertEquals(webhookStatusForResults(1), 503);
});
