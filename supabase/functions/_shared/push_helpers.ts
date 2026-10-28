/** Shared pure helpers for send-reminder-push (testable without APNs/Supabase). */

export const APNS_TOKEN_PATTERN = /^[0-9a-f]{64}$/i;
export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** How long APNs should store an undelivered alert (missed while the phone is offline). */
export const APNS_EXPIRATION_TTL_SECONDS = 24 * 60 * 60;

export const APNS_MAX_ATTEMPTS = 3;
export const APNS_RETRY_DELAYS_MS = [200, 400] as const;
export const APNS_REQUEST_TIMEOUT_MS = 10_000;
export const APNS_ALERT_CATEGORY = "reminder";

export type ReminderRecord = {
  id: string;
  user_id: string;
  text: string;
  routine_id?: string | null;
  routine_fired_at?: string | null;
};

export type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: ReminderRecord;
  old_record?: unknown;
};

const encoder = new TextEncoder();
const APNS_MAX_PAYLOAD_BYTES = 4096;

function validReminderText(text: unknown): boolean {
  if (typeof text !== "string") return false;
  // Match char_length(trim(text)) and the raw-length constraint in Postgres.
  // SQL trim removes ASCII spaces, not tabs, newlines or other whitespace.
  const trimmedLength = [...text.replace(/^ +| +$/g, "")].length;
  return trimmedLength >= 1 && trimmedLength <= 500 && [...text].length <= 1000;
}

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
      typeof record.id !== "string" ||
      typeof record.user_id !== "string" ||
      !UUID_PATTERN.test(record.id) ||
      !UUID_PATTERN.test(record.user_id) ||
      !validReminderText(record.text)
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
    const record = reminderBody.record;
    const old = reminderBody.old_record;
    const routineAlert = reminderBody.type === "UPDATE" && record &&
      "routine_fired_at" in record && typeof record.routine_fired_at === "string" &&
      Number.isFinite(Date.parse(record.routine_fired_at)) &&
      "routine_id" in record && typeof record.routine_id === "string" && UUID_PATTERN.test(record.routine_id) &&
      typeof record.id === "string" && UUID_PATTERN.test(record.id) &&
      validReminderText(record.text) &&
      typeof old === "object" && old !== null && "routine_fired_at" in old &&
      old.routine_fired_at !== record.routine_fired_at;
    return { ok: true, kind: "process", sendsAlert: Boolean(routineAlert), userId };
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

export function headersWithAuthorization(
  headers: Record<string, string>,
  jwt: string,
): Record<string, string> {
  return { ...headers, authorization: `bearer ${jwt}` };
}

export async function deliverWithRetries(input: {
  headers: Record<string, string>;
  stopOnUncertainDelivery?: boolean;
  send: (
    headers: Record<string, string>,
  ) => Promise<ApnsOutcome>;
  nextJwt: () => Promise<string>;
  onExpiredJwt: () => void;
  onPrune: (outcome: Extract<ApnsOutcome, { kind: "prune" }>) => Promise<void>;
  sleep: (ms: number) => Promise<void>;
}): Promise<"sent" | "failed" | "retryable" | "invalid"> {
  let headers = input.headers;
  let lastRetryable = false;

  for (let attempt = 0; attempt < APNS_MAX_ATTEMPTS; attempt++) {
    const outcome = await input.send(headers);
    // Starts are not idempotent: APNs may have accepted the request even
    // though its response was lost. Preserve that uncertainty and the lease.
    if (outcome.kind === "uncertain" && input.stopOnUncertainDelivery) {
      return "retryable";
    }
    if (outcome.kind === "sent") return "sent";
    if (outcome.kind === "prune") {
      await input.onPrune(outcome);
      return "invalid";
    }
    if (outcome.kind === "permanent") return "failed";

    lastRetryable = true;
    if (outcome.kind === "expired_jwt") {
      input.onExpiredJwt();
      headers = headersWithAuthorization(headers, await input.nextJwt());
    }
    if (attempt < APNS_MAX_ATTEMPTS - 1) {
      await input.sleep(delayMsForAttempt(attempt));
    }
  }

  return lastRetryable ? "retryable" : "failed";
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
  | { kind: "uncertain"; status: number; reason: string }
  | { kind: "retryable"; status: number; reason: string }
  | { kind: "prune"; status: number; reason: string; invalidatedAtMs?: number }
  | { kind: "expired_jwt"; status: number; reason: string }
  | { kind: "permanent"; status: number; reason: string };

const PRUNE_REASONS = new Set([
  "BadDeviceToken",
  "Unregistered",
  "ExpiredToken",
  "DeviceTokenNotForTopic",
]);

export function classifyApnsResponse(
  status: number,
  body: string,
): ApnsOutcome {
  if (status >= 200 && status < 300) return { kind: "sent" };

  const reason = parseApnsReason(body);
  if (status === 403 && reason === "ExpiredProviderToken") {
    return { kind: "expired_jwt", status, reason };
  }
  if (status === 410 || PRUNE_REASONS.has(reason)) {
    let invalidatedAtMs: number | undefined;
    if (status === 410) {
      try {
        const timestamp = JSON.parse(body)?.timestamp;
        if (typeof timestamp === "number" && Number.isSafeInteger(timestamp) &&
          timestamp >= 0 && timestamp <= 8.64e15) {
          invalidatedAtMs = timestamp;
        }
      } catch { /* A missing timestamp still permits revision-guarded cleanup. */ }
    }
    return {
      kind: "prune", status, reason,
      ...(invalidatedAtMs === undefined ? {} : { invalidatedAtMs }),
    };
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
  const payload = {
    aps: {
      // Body-only alert: no title/header. System draws the full-width
      // notification bar with the user's Liquid Glass (Clear) setting.
      alert: { body: "" },
      sound: "default",
      category: APNS_ALERT_CATEGORY,
      "content-available": 1,
    },
    reminder_id: record.id,
  };
  let remaining = APNS_MAX_PAYLOAD_BYTES -
    encoder.encode(JSON.stringify(payload)).length;
  // Include JSON escaping as well as UTF-8 encoding in the byte budget.
  for (const character of record.text) {
    const bytes = encoder.encode(JSON.stringify(character)).length - 2;
    if (bytes > remaining) break;
    payload.aps.alert.body += character;
    remaining -= bytes;
  }
  return JSON.stringify(payload);
}

/** Webhook / pg_net should retry the whole job only when APNs might succeed later. */
export function webhookStatusForResults(retryable: number): number {
  return retryable > 0 ? 503 : 200;
}
