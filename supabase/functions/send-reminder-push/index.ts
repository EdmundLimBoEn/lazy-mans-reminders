import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  boardLines,
  buildLiveActivityHeaders,
  buildLiveActivityPayload,
  decideLiveActivity,
  LIVE_ACTIVITY_FALLBACK_MAX_LINES,
  liveActivityStaleDateUnix,
  parseLiveActivityToken,
  parseStartedAtMs,
} from "../_shared/live_activity.ts";
import {
  APNS_MAX_ATTEMPTS,
  APNS_REQUEST_TIMEOUT_MS,
  APNS_TOKEN_PATTERN,
  apnsCollapseId,
  apnsExpirationUnix,
  apnsHostForEnvironment,
  base64url,
  buildApnsHeaders,
  buildApnsPayload,
  classifyApnsResponse,
  classifyWebhookPayload,
  delayMsForAttempt,
  webhookStatusForResults,
  type ReminderRecord,
} from "../_shared/push_helpers.ts";

const encoder = new TextEncoder();
const APNS_JWT_TTL_MS = 50 * 60 * 1000;

let cachedAPNSJWT: { value: string; createdAt: number } | undefined;

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function apnsJWT(): Promise<string> {
  const now = Date.now();
  if (cachedAPNSJWT && now - cachedAPNSJWT.createdAt < APNS_JWT_TTL_MS) {
    return cachedAPNSJWT.value;
  }

  const keyID = requiredEnv("APNS_KEY_ID");
  const teamID = requiredEnv("APNS_TEAM_ID");
  const pem = requiredEnv("APNS_PRIVATE_KEY").replaceAll("\\n", "\n");
  const keyBody = pem.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    "",
  );
  if (!keyBody) {
    throw new Error("APNS_PRIVATE_KEY is not a valid PKCS#8 PEM key");
  }

  const der = Uint8Array.from(
    atob(keyBody),
    (character) => character.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = base64url(
    JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) }),
  );
  const unsigned = `${header}.${claims}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      encoder.encode(unsigned),
    ),
  );
  if (signature.length !== 64) {
    throw new Error(
      `Unexpected APNs ES256 signature length: ${signature.length}`,
    );
  }

  const value = `${unsigned}.${base64url(signature)}`;
  cachedAPNSJWT = { value, createdAt: now };
  return value;
}

function invalidateAPNSJWT(): void {
  cachedAPNSJWT = undefined;
}

async function secretsMatch(
  expected: string,
  actual: string | null,
): Promise<boolean> {
  const [expectedHash, actualHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
    crypto.subtle.digest("SHA-256", encoder.encode(actual ?? "")),
  ]);
  const expectedBytes = new Uint8Array(expectedHash);
  const actualBytes = new Uint8Array(actualHash);
  return actual !== null && timingSafeEqual(expectedBytes, actualBytes);
}

// Service-role client is untyped here — Edge Function env has no generated DB types.
// deno-lint-ignore no-explicit-any
type ServiceClient = { from: (table: string) => any };
type DeviceSendResult = "sent" | "retryable" | "failed";

type DeviceRow = {
  token: string;
  user_id: string;
  environment: string;
  push_to_start_token: string | null;
  activity_push_token: string | null;
  activity_started_at: string | null;
};

const DEVICE_SELECT =
  "token, user_id, environment, push_to_start_token, activity_push_token, activity_started_at";

async function pruneAlertToken(
  supabase: ServiceClient,
  userId: string,
  token: string,
): Promise<void> {
  const { error: deleteError } = await supabase
    .from("device_tokens")
    .delete()
    .eq("token", token)
    .eq("user_id", userId);
  if (deleteError) {
    console.error("Could not remove expired APNs token", deleteError);
  }
}

async function clearLiveActivityColumn(
  supabase: ServiceClient,
  userId: string,
  alertToken: string,
  column: "push_to_start_token" | "activity_push_token" | "activity_started_at",
): Promise<void> {
  const { error } = await supabase
    .from("device_tokens")
    .update({ [column]: null })
    .eq("token", alertToken)
    .eq("user_id", userId);
  if (error) {
    console.error(`Could not clear ${column}`, error);
  }
}

async function markActivityStarted(
  supabase: ServiceClient,
  userId: string,
  alertToken: string,
  startedAt: string,
): Promise<void> {
  const { error } = await supabase
    .from("device_tokens")
    .update({
      activity_started_at: startedAt,
      activity_push_token: null,
    })
    .eq("token", alertToken)
    .eq("user_id", userId);
  if (error) {
    console.error("Could not record Live Activity start", error);
  }
}

async function markActivityEnded(
  supabase: ServiceClient,
  userId: string,
  alertToken: string,
): Promise<void> {
  const { error } = await supabase
    .from("device_tokens")
    .update({
      activity_push_token: null,
      activity_started_at: null,
    })
    .eq("token", alertToken)
    .eq("user_id", userId);
  if (error) {
    console.error("Could not record Live Activity end", error);
  }
}

async function sendOnce(input: {
  host: string;
  token: string;
  headers: Record<string, string>;
  body: string;
}): Promise<
  ReturnType<typeof classifyApnsResponse> | {
    kind: "retryable";
    status: number;
    reason: string;
  }
> {
  try {
    const response = await fetch(`${input.host}/3/device/${input.token}`, {
      method: "POST",
      headers: input.headers,
      body: input.body,
      signal: AbortSignal.timeout(APNS_REQUEST_TIMEOUT_MS),
    });
    const responseBody = await response.text();
    const outcome = classifyApnsResponse(response.status, responseBody);
    if (outcome.kind !== "sent") {
      console.error("APNs rejected push", response.status, responseBody);
    }
    return outcome;
  } catch (error) {
    console.error("APNs request failed", error);
    return { kind: "retryable", status: 0, reason: "network" };
  }
}

async function sendWithRetries(input: {
  host: string;
  token: string;
  headers: Record<string, string>;
  body: string;
  onPrune: () => Promise<void>;
}): Promise<DeviceSendResult> {
  let lastRetryable = false;

  for (let attempt = 0; attempt < APNS_MAX_ATTEMPTS; attempt++) {
    const outcome = await sendOnce({
      host: input.host,
      token: input.token,
      headers: input.headers,
      body: input.body,
    });

    if (outcome.kind === "sent") return "sent";
    if (outcome.kind === "prune") {
      await input.onPrune();
      return "failed";
    }
    if (outcome.kind === "permanent") return "failed";

    lastRetryable = true;
    if (outcome.kind === "expired_jwt") invalidateAPNSJWT();
    if (attempt < APNS_MAX_ATTEMPTS - 1) {
      await sleep(delayMsForAttempt(attempt));
    }
  }

  return lastRetryable ? "retryable" : "failed";
}

async function sendAlertToDevice(input: {
  supabase: ServiceClient;
  userId: string;
  token: string;
  environment: string;
  topic: string;
  record: ReminderRecord;
}): Promise<DeviceSendResult> {
  if (!APNS_TOKEN_PATTERN.test(input.token)) {
    console.error("Skipping malformed APNs token");
    return "failed";
  }

  const jwt = await apnsJWT();
  return await sendWithRetries({
    host: apnsHostForEnvironment(input.environment),
    token: input.token,
    headers: buildApnsHeaders({
      jwt,
      topic: input.topic,
      collapseId: apnsCollapseId(input.record.id),
      expirationUnix: apnsExpirationUnix(),
    }),
    body: buildApnsPayload(input.record),
    onPrune: () => pruneAlertToken(input.supabase, input.userId, input.token),
  });
}

async function sendLiveActivityEvent(input: {
  supabase: ServiceClient;
  device: DeviceRow;
  bundleId: string;
  event: "start" | "update" | "end";
  lines: string[];
  alertBody?: string;
  destination: "push-to-start" | "activity";
}): Promise<DeviceSendResult> {
  const token = input.destination === "push-to-start"
    ? parseLiveActivityToken(input.device.push_to_start_token)
    : parseLiveActivityToken(input.device.activity_push_token);
  if (!token) return "failed";

  const jwt = await apnsJWT();
  const nowUnix = Math.floor(Date.now() / 1000);
  const pruneColumn = input.destination === "push-to-start"
    ? "push_to_start_token" as const
    : "activity_push_token" as const;

  return await sendWithRetries({
    host: apnsHostForEnvironment(input.device.environment),
    token,
    headers: buildLiveActivityHeaders({ jwt, bundleId: input.bundleId }),
    body: buildLiveActivityPayload({
      event: input.event,
      lines: input.lines,
      timestamp: nowUnix,
      alertBody: input.alertBody,
      staleDate: liveActivityStaleDateUnix(nowUnix),
    }),
    onPrune: () =>
      clearLiveActivityColumn(
        input.supabase,
        input.device.user_id,
        input.device.token,
        pruneColumn,
      ),
  });
}

async function syncLiveActivity(input: {
  supabase: ServiceClient;
  device: DeviceRow;
  bundleId: string;
  lines: string[];
  alertBody?: string;
}): Promise<{ results: DeviceSendResult[]; deliveredAlert: boolean }> {
  const decision = decideLiveActivity({
    lines: input.lines,
    hasPushToStartToken: parseLiveActivityToken(input.device.push_to_start_token) !=
      null,
    hasActivityToken: parseLiveActivityToken(input.device.activity_push_token) !=
      null,
    startedAtMs: parseStartedAtMs(input.device.activity_started_at),
    nowMs: Date.now(),
  });

  if (decision.kind === "noop") {
    return { results: [], deliveredAlert: false };
  }

  const startedAt = new Date().toISOString();

  if (decision.kind === "start") {
    const result = await sendLiveActivityEvent({
      ...input,
      event: "start",
      destination: "push-to-start",
    });
    if (result === "sent") {
      await markActivityStarted(
        input.supabase,
        input.device.user_id,
        input.device.token,
        startedAt,
      );
    }
    return { results: [result], deliveredAlert: result === "sent" && Boolean(input.alertBody) };
  }

  if (decision.kind === "update") {
    const result = await sendLiveActivityEvent({
      ...input,
      event: "update",
      destination: "activity",
    });
    if (result === "sent") {
      return {
        results: [result],
        deliveredAlert: Boolean(input.alertBody),
      };
    }
    if (parseLiveActivityToken(input.device.push_to_start_token) == null) {
      return { results: [result], deliveredAlert: false };
    }
    const started = await sendLiveActivityEvent({
      ...input,
      event: "start",
      destination: "push-to-start",
    });
    if (started === "sent") {
      await markActivityStarted(
        input.supabase,
        input.device.user_id,
        input.device.token,
        startedAt,
      );
    }
    return {
      results: [result, started],
      deliveredAlert: started === "sent" && Boolean(input.alertBody),
    };
  }

  if (decision.kind === "end") {
    const result = await sendLiveActivityEvent({
      ...input,
      event: "end",
      destination: "activity",
    });
    if (result === "sent" || result === "failed") {
      await markActivityEnded(
        input.supabase,
        input.device.user_id,
        input.device.token,
      );
    }
    return { results: [result], deliveredAlert: false };
  }

  const start = await sendLiveActivityEvent({
    ...input,
    event: "start",
    destination: "push-to-start",
  });
  if (start !== "sent") {
    return { results: [start], deliveredAlert: false };
  }
  const end = await sendLiveActivityEvent({
    ...input,
    event: "end",
    destination: "activity",
    alertBody: undefined,
  });
  await markActivityStarted(
    input.supabase,
    input.device.user_id,
    input.device.token,
    startedAt,
  );
  return {
    results: [start, end],
    deliveredAlert: Boolean(input.alertBody),
  };
}

async function loadBoardLines(
  supabase: ServiceClient,
  userId: string,
  insertedText?: string,
): Promise<string[]> {
  const [{ data: reminders, error: reminderError }, { data: prefs }] =
    await Promise.all([
      supabase
        .from("reminders")
        .select("text")
        .eq("user_id", userId)
        .eq("is_done", false)
        .order("sort_order", { ascending: true })
        .order("created_at", { ascending: true }),
      supabase
        .from("lock_screen_prefs")
        .select("max_lines")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);
  if (reminderError) {
    console.error("Could not load reminders for Live Activity", reminderError);
  }
  const texts = (reminders ?? []).map((row: { text: string }) => row.text);
  if (insertedText && !texts.includes(insertedText)) texts.push(insertedText);
  const limit = typeof prefs?.max_lines === "number"
    ? prefs.max_lines
    : LIVE_ACTIVITY_FALLBACK_MAX_LINES;
  return boardLines(texts, limit);
}

async function loadDevicesForUser(
  supabase: ServiceClient,
  userId: string,
): Promise<DeviceRow[] | { error: unknown }> {
  const { data, error } = await supabase
    .from("device_tokens")
    .select(DEVICE_SELECT)
    .eq("user_id", userId);
  if (error) return { error };
  return (data ?? []) as DeviceRow[];
}

async function loadDevicesForRefresh(
  supabase: ServiceClient,
): Promise<DeviceRow[] | { error: unknown }> {
  const { data, error } = await supabase
    .from("device_tokens")
    .select(DEVICE_SELECT)
    .or("push_to_start_token.not.is.null,activity_push_token.not.is.null");
  if (error) return { error };
  return (data ?? []) as DeviceRow[];
}

function summarize(results: DeviceSendResult[]): Response {
  const sent = results.filter((result) => result === "sent").length;
  const retryable = results.filter((result) => result === "retryable").length;
  const failed = results.length - sent - retryable;
  return Response.json({ sent, failed, retryable }, {
    status: webhookStatusForResults(retryable),
  });
}

async function syncDevices(input: {
  supabase: ServiceClient;
  devices: DeviceRow[];
  bundleId: string;
  lines: string[];
  alertRecord?: ReminderRecord;
}): Promise<DeviceSendResult[]> {
  const results: DeviceSendResult[] = [];
  for (const device of input.devices) {
    const live = await syncLiveActivity({
      supabase: input.supabase,
      device,
      bundleId: input.bundleId,
      lines: input.lines,
      alertBody: input.alertRecord?.text,
    });
    results.push(...live.results);
    if (input.alertRecord && !live.deliveredAlert) {
      results.push(
        await sendAlertToDevice({
          supabase: input.supabase,
          userId: device.user_id,
          token: device.token,
          environment: device.environment,
          topic: input.bundleId,
          record: input.alertRecord,
        }),
      );
    }
  }
  return results;
}

Deno.serve(async (request) => {
  const webhookSecret = Deno.env.get("WEBHOOK_SECRET");
  if (
    !webhookSecret ||
    !await secretsMatch(webhookSecret, request.headers.get("x-webhook-secret"))
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (request.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { allow: "POST" },
    });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const check = classifyWebhookPayload(payload);
  if (!check.ok) {
    return new Response(check.message, { status: check.status });
  }
  if (check.kind === "ignore") {
    return new Response("Ignored", { status: 202 });
  }

  let supabase;
  let bundleId: string;
  try {
    supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    await apnsJWT();
    bundleId = requiredEnv("APNS_TOPIC");
  } catch (error) {
    console.error("Edge Function configuration error", error);
    return new Response("Server configuration error", { status: 500 });
  }

  if (check.kind === "refresh") {
    const devices = await loadDevicesForRefresh(supabase);
    if ("error" in devices) {
      console.error("Could not load device tokens", devices.error);
      return new Response("Could not load device tokens", { status: 500 });
    }
    const byUser = new Map<string, DeviceRow[]>();
    for (const device of devices) {
      const list = byUser.get(device.user_id) ?? [];
      list.push(device);
      byUser.set(device.user_id, list);
    }
    const results: DeviceSendResult[] = [];
    for (const [userId, userDevices] of byUser) {
      const lines = await loadBoardLines(supabase, userId);
      results.push(
        ...await syncDevices({
          supabase,
          devices: userDevices,
          bundleId,
          lines,
        }),
      );
    }
    return summarize(results);
  }

  const devices = await loadDevicesForUser(supabase, check.userId);
  if ("error" in devices) {
    console.error("Could not load device tokens", devices.error);
    return new Response("Could not load device tokens", { status: 500 });
  }
  if (!devices.length) {
    return Response.json({ sent: 0, failed: 0, retryable: 0 });
  }

  const record = (payload as { record?: ReminderRecord }).record;
  const lines = await loadBoardLines(
    supabase,
    check.userId,
    check.sendsAlert ? record?.text : undefined,
  );
  const results = await syncDevices({
    supabase,
    devices,
    bundleId,
    lines,
    alertRecord: check.sendsAlert && record ? record : undefined,
  });
  return summarize(results);
});
