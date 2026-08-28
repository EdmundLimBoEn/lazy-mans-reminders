/** Shared pure helpers for send-reminder-push (testable without APNs/Supabase). */

export const APNS_TOKEN_PATTERN = /^[0-9a-f]{64}$/i;
export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** How long APNs should store an undelivered alert (missed while the phone is offline). */
export const APNS_EXPIRATION_TTL_SECONDS = 24 * 60 * 60;

export const APNS_MAX_ATTEMPTS = 3;
export const APNS_RETRY_DELAYS_MS = [200, 400] as const;
export const APNS_REQUEST_TIMEOUT_MS = 10_000;

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
  | { ok: true; kind: "process"; sendsAlert: boolean; userId: string }
  | { ok: true; kind: "refresh" }
  | { ok: true; kind: "ignore" }
  | { ok: false; status: 400; message: string };

function recordUserId(record: unknown): string | null {
  if (typeof record !== "object" || record === null) return null;
  if (!("user_id" in record) || typeof record.user_id !== "string") return null;
  return UUID_PATTERN.test(record.user_id) ? record.user_id : null;
}

/** Decide whether a parsed webhook body should send a push, be ignored, or rejected. */
export function classifyWebhookPayload(payload: unknown): PayloadCheck {
  if (typeof payload !== "object" || payload === null || !("type" in payload)) {
    return { ok: false, status: 400, message: "Invalid webhook payload" };
  }

  const body = payload as { type?: unknown };
  if (body.type === "live_activity_refresh") {
    return { ok: true, kind: "refresh" };
  }

  if (!("table" in payload) || !("schema" in payload)) {
    return { ok: false, status: 400, message: "Invalid webhook payload" };
  }

  const reminderBody = payload as Partial<WebhookPayload>;
  if (reminderBody.table !== "reminders" || reminderBody.schema !== "public") {
    return { ok: true, kind: "ignore" };
  }

  if (reminderBody.type === "INSERT") {
    const record = reminderBody.record;
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
    return {
      ok: true,
      kind: "process",
      sendsAlert: true,
      userId: record.user_id,
    };
  }

  if (reminderBody.type === "UPDATE" || reminderBody.type === "DELETE") {
    const userId = recordUserId(reminderBody.record);
    if (!userId) {
      return { ok: false, status: 400, message: "Invalid webhook payload" };
    }
    return { ok: true, kind: "process", sendsAlert: false, userId };
  }

  return { ok: true, kind: "ignore" };
}

export function apnsHostForEnvironment(environment: string): string {
  return environment === "development"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}

export function apnsExpirationUnix(nowMs = Date.now()): number {
  return Math.floor(nowMs / 1000) + APNS_EXPIRATION_TTL_SECONDS;
}

/** Collapse retries / webhook redeliveries onto one banner per reminder. */
export function apnsCollapseId(reminderId: string): string {
  return reminderId;
}

export function delayMsForAttempt(attempt: number): number {
  return APNS_RETRY_DELAYS_MS[attempt] ??
    APNS_RETRY_DELAYS_MS[APNS_RETRY_DELAYS_MS.length - 1];
}

export function parseApnsReason(body: string): string {
  try {
    const parsed = JSON.parse(body) as { reason?: unknown };
    return typeof parsed.reason === "string" ? parsed.reason : "";
  } catch {
    return "";
  }
}

export type ApnsOutcome =
  | { kind: "sent" }
  | { kind: "retryable"; status: number; reason: string }
  | { kind: "prune"; status: number; reason: string }
  | { kind: "expired_jwt"; status: number; reason: string }
  | { kind: "permanent"; status: number; reason: string };

const PRUNE_REASONS = new Set([
  "BadDeviceToken",
  "Unregistered",
  "ExpiredToken",
  "DeviceTokenNotForTopic",
]);

export function classifyApnsResponse(status: number, body: string): ApnsOutcome {
  if (status >= 200 && status < 300) return { kind: "sent" };

  const reason = parseApnsReason(body);
  if (status === 403 && reason === "ExpiredProviderToken") {
    return { kind: "expired_jwt", status, reason };
  }
  if (status === 410 || PRUNE_REASONS.has(reason)) {
    return { kind: "prune", status, reason };
  }
  if (status === 429 || status >= 500) {
    return { kind: "retryable", status, reason };
  }
  return { kind: "permanent", status, reason };
}

export function buildApnsHeaders(input: {
  jwt: string;
  topic: string;
  collapseId: string;
  expirationUnix: number;
}): Record<string, string> {
  return {
    authorization: `bearer ${input.jwt}`,
    "content-type": "application/json",
    "apns-topic": input.topic,
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": String(input.expirationUnix),
    "apns-collapse-id": input.collapseId,
  };
}

export function buildApnsPayload(record: ReminderRecord): string {
  return JSON.stringify({
    aps: {
      // Body-only alert: no title/header. System draws the full-width
      // notification bar with the user's Liquid Glass (Clear) setting.
      alert: { body: record.text },
      sound: "default",
      "content-available": 1,
    },
    reminder_id: record.id,
  });
}

/** Webhook / pg_net should retry the whole job only when APNs might succeed later. */
export function webhookStatusForResults(retryable: number): number {
  return retryable > 0 ? 503 : 200;
}
