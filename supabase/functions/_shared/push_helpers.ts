/** Shared pure helpers for send-reminder-push (testable without APNs/Supabase). */

export const APNS_TOKEN_PATTERN = /^[0-9a-f]{64}$/i;
export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ReminderRecord = {
  id: string;
  user_id: string;
  text: string;
};

export type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: ReminderRecord;
};

const encoder = new TextEncoder();

export function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? encoder.encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

export type PayloadCheck =
  | { ok: true; kind: "process" }
  | { ok: true; kind: "ignore" }
  | { ok: false; status: 400; message: string };

/** Decide whether a parsed webhook body should send a push, be ignored, or rejected. */
export function classifyWebhookPayload(payload: unknown): PayloadCheck {
  if (
    typeof payload !== "object" ||
    payload === null ||
    !("type" in payload) ||
    !("table" in payload) ||
    !("schema" in payload)
  ) {
    return { ok: false, status: 400, message: "Invalid webhook payload" };
  }

  const body = payload as Partial<WebhookPayload>;
  if (
    body.type !== "INSERT" ||
    body.table !== "reminders" ||
    body.schema !== "public"
  ) {
    return { ok: true, kind: "ignore" };
  }

  const record = body.record;
  if (
    !record ||
    typeof record !== "object" ||
    !UUID_PATTERN.test(record.id) ||
    !UUID_PATTERN.test(record.user_id) ||
    typeof record.text !== "string" ||
    record.text.length === 0 ||
    record.text.length > 500
  ) {
    return { ok: false, status: 400, message: "Invalid webhook payload" };
  }

  return { ok: true, kind: "process" };
}

export function apnsHostForEnvironment(environment: string): string {
  return environment === "development"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}
