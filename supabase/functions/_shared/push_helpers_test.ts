import {
  assertEquals,
  assertFalse,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  APNS_TOKEN_PATTERN,
  apnsHostForEnvironment,
  base64url,
  classifyWebhookPayload,
  UUID_PATTERN,
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
});
