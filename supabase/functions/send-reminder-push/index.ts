import { pruneAlertToken } from "../_shared/alert_token_store.ts";
import { markActivityEnded } from "../_shared/live_activity_store.ts";
import {
  deliverDevices,
  DEVICE_SELECT,
  type DeviceRow,
  type ServiceClient,
} from "../_shared/device_delivery.ts";
import {
  reconcileLiveActivity,
  type SendResult,
} from "../_shared/live_activity_lifecycle.ts";
import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.112.1";
import {
  buildLiveActivityHeaders,
  buildLiveActivityPayload,
  liveActivityStaleDateUnix,
  parseLiveActivityToken,
} from "../_shared/live_activity.ts";
import {
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
  deliverWithRetries,
  type ReminderRecord,
  webhookStatusForResults,
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

type DeviceSendResult = SendResult;

async function clearLiveActivityColumn(
  supabase: ServiceClient,
  userId: string,
  alertToken: string,
  column:
    | "push_to_start_token"
    | "activity_push_token"
    | "activity_started_at"
    | "retiring_activity_push_token",
  expectedToken?: string | null,
): Promise<void> {
  const patch = column === "activity_push_token"
    ? { activity_push_token: null, activity_started_at: null }
    : { [column]: null };
  let query = supabase
    .from("device_tokens")
    .update(patch)
    .eq("token", alertToken)
    .eq("user_id", userId);
  if (expectedToken) query = query.eq(column, expectedToken);
  const { error } = await query;
  if (error) {
    console.error(`Could not clear ${column}`, error);
  }
}

async function stampActivityStartedIfMissing(
  supabase: ServiceClient,
  userId: string,
  alertToken: string,
  startedAt: string,
): Promise<void> {
  const { error } = await supabase
    .from("device_tokens")
    .update({ activity_started_at: startedAt })
    .eq("token", alertToken)
    .eq("user_id", userId)
    .is("activity_started_at", null);
  if (error) {
    console.error("Could not record Live Activity start time", error);
  }
}

async function markActivityStarted(
  supabase: ServiceClient,
  device: DeviceRow,
  startedAt: string,
  replacing: boolean,
  leaseId: string,
): Promise<void> {
  // The phone may upload the new token before APNs returns. Clear only the
  // token we read, never an acknowledgement that arrived during delivery.
  const { error } = await supabase.rpc("complete_live_activity_start", {
    p_lease_id: leaseId,
    p_device_token: device.token,
    p_user_id: device.user_id,
    p_previous_token: device.activity_push_token,
    p_started_at: startedAt,
    p_replacing: replacing,
  });
  if (error) throw new Error("Could not record Live Activity start");
}

async function sendOnce(input: {
  assertCurrent: () => void;
  host: string;
  token: string;
  headers: Record<string, string>;
  body: string;
}): Promise<
  ReturnType<typeof classifyApnsResponse> | {
    kind: "uncertain";
    status: number;
    reason: string;
  }
> {
  input.assertCurrent();
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
    return { kind: "uncertain", status: 0, reason: "network" };
  }
}

async function sendWithRetries(input: {
  assertCurrent: () => void;
  stopOnUncertainDelivery?: boolean;
  host: string;
  token: string;
  headers: Record<string, string>;
  body: string;
  onPrune: Parameters<typeof deliverWithRetries>[0]["onPrune"];
}): Promise<DeviceSendResult> {
  return await deliverWithRetries({
    stopOnUncertainDelivery: input.stopOnUncertainDelivery,
    headers: input.headers,
    send: (headers) => sendOnce({ ...input, headers }),
    nextJwt: apnsJWT,
    onExpiredJwt: invalidateAPNSJWT,
    onPrune: input.onPrune,
    sleep,
  });
}

async function sendAlertToDevice(input: {
  assertCurrent: () => void;
  supabase: ServiceClient;
  device: DeviceRow;
  topic: string;
  record: ReminderRecord;
}): Promise<DeviceSendResult> {
  if (!APNS_TOKEN_PATTERN.test(input.device.token)) {
    console.error("Skipping malformed APNs token");
    return "failed";
  }

  const jwt = await apnsJWT();
  return await sendWithRetries({
    assertCurrent: input.assertCurrent,
    host: apnsHostForEnvironment(input.device.environment),
    token: input.device.token,
    headers: buildApnsHeaders({
      jwt,
      topic: input.topic,
      collapseId: apnsCollapseId(input.record.id),
      expirationUnix: apnsExpirationUnix(),
    }),
    body: buildApnsPayload(input.record),
    onPrune: (outcome) => pruneAlertToken(input.supabase, input.device, outcome),
  });
}

async function sendLiveActivityEvent(input: {
  assertCurrent: () => void;
  supabase: ServiceClient;
  device: DeviceRow;
  bundleId: string;
  event: "start" | "update" | "end";
  lines: string[];
  alertBody?: string;
  destination: "push-to-start" | "activity" | "retiring";
  quiet?: boolean;
}): Promise<DeviceSendResult> {
  const token = input.destination === "push-to-start"
    ? parseLiveActivityToken(input.device.push_to_start_token)
    : parseLiveActivityToken(
      input.destination === "retiring"
        ? input.device.retiring_activity_push_token
        : input.device.activity_push_token,
    );
  if (!token) return "failed";

  const jwt = await apnsJWT();
  const nowUnix = Math.floor(Date.now() / 1000);
  const pruneColumn = input.destination === "push-to-start"
    ? "push_to_start_token" as const
    : input.destination === "retiring"
    ? "retiring_activity_push_token" as const
    : "activity_push_token" as const;

  return await sendWithRetries({
    assertCurrent: input.assertCurrent,
    host: apnsHostForEnvironment(input.device.environment),
    stopOnUncertainDelivery: input.event === "start",
    token,
    headers: buildLiveActivityHeaders({
      jwt,
      bundleId: input.bundleId,
      event: input.event,
      quiet: input.quiet,
    }),
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
        token,
      ),
  });
}

async function syncLiveActivity(input: {
  assertCurrent: () => void;
  supabase: ServiceClient;
  device: DeviceRow;
  bundleId: string;
  lines: string[];
  alertBody?: string;
  quiet?: boolean;
}): Promise<{ results: DeviceSendResult[]; deliveredAlert: boolean }> {
  return await reconcileLiveActivity({
    lines: input.lines,
    activityToken: parseLiveActivityToken(input.device.activity_push_token),
    startToken: parseLiveActivityToken(input.device.push_to_start_token),
    retiringToken: parseLiveActivityToken(
      input.device.retiring_activity_push_token,
    ),
    startedAt: input.device.activity_started_at,
    nowMs: Date.now(),
    quiet: input.quiet,
    hasAlert: Boolean(input.alertBody),
    send: (event, destination) =>
      sendLiveActivityEvent({
        ...input,
        event,
        destination,
        alertBody: destination === "retiring" ? undefined : input.alertBody,
      }),
    claimStart: async (invalidActivity) => {
      const leaseId = crypto.randomUUID();
      const { data, error } = await input.supabase.rpc(
        "claim_live_activity_start",
        {
          p_device_token: input.device.token,
          p_user_id: input.device.user_id,
          p_lease_id: leaseId,
          p_expected_token: invalidActivity
            ? null
            : input.device.activity_push_token,
          p_expected_started_at: invalidActivity
            ? null
            : input.device.activity_started_at,
        },
      );
      if (error) throw new Error("Could not claim Live Activity start");
      return data === true ? leaseId : null;
    },
    releaseStart: async (leaseId) => {
      const { error } = await input.supabase.rpc(
        "release_live_activity_start",
        {
          p_device_token: input.device.token,
          p_user_id: input.device.user_id,
          p_lease_id: leaseId,
        },
      );
      if (error) throw new Error("Could not release Live Activity start");
    },
    recordStart: (replacing, leaseId) =>
      markActivityStarted(
        input.supabase,
        input.device,
        new Date().toISOString(),
        replacing,
        leaseId,
      ),
    recordEnd: () =>
      markActivityEnded(
        input.supabase,
        input.device.user_id,
        input.device.token,
        input.device.activity_push_token,
        input.device.activity_started_at,
      ),
    recordAdoption: () =>
      stampActivityStartedIfMissing(
        input.supabase,
        input.device.user_id,
        input.device.token,
        new Date().toISOString(),
      ),
    clearRetiring: () =>
      clearLiveActivityColumn(
        input.supabase,
        input.device.user_id,
        input.device.token,
        "retiring_activity_push_token",
        input.device.retiring_activity_push_token,
      ),
  });
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
    .or(
      "push_to_start_token.not.is.null,activity_push_token.not.is.null,retiring_activity_push_token.not.is.null",
    );
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
  alertCandidate?: ReminderRecord;
  quiet?: boolean;
}): Promise<DeviceSendResult[]> {
  return await deliverDevices({
    ...input,
    deliver: async (device, content, assertCurrent) => {
      const live = await syncLiveActivity({
        supabase: input.supabase,
        device,
        bundleId: input.bundleId,
        lines: content.lines,
        alertBody: content.alertRecord?.text,
        quiet: input.quiet,
        assertCurrent,
      });
      if (content.alertRecord && !live.deliveredAlert) {
        live.results.push(
          await sendAlertToDevice({
            supabase: input.supabase,
            device,
            topic: input.bundleId,
            record: content.alertRecord,
            assertCurrent,
          }),
        );
      }
      return live.results;
    },
  });
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
    for (const userDevices of byUser.values()) {
      try {
        results.push(
          ...await syncDevices({
            supabase,
            devices: userDevices,
            bundleId,
            quiet: true,
          }),
        );
      } catch {
        console.error(
          "Live Activity refresh failed; retaining existing banners",
        );
        results.push("retryable");
      }
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
  const results = await syncDevices({
    supabase,
    devices,
    bundleId,
    alertCandidate: check.sendsAlert ? record : undefined,
  });
  return summarize(results);
});
