import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
  type WebhookPayload,
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

async function pruneToken(
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

async function sendOnce(input: {
  host: string;
  token: string;
  topic: string;
  record: ReminderRecord;
}): Promise<ReturnType<typeof classifyApnsResponse> | { kind: "retryable"; status: number; reason: string }> {
  try {
    const jwt = await apnsJWT();
    const response = await fetch(`${input.host}/3/device/${input.token}`, {
      method: "POST",
      headers: buildApnsHeaders({
        jwt,
        topic: input.topic,
        collapseId: apnsCollapseId(input.record.id),
        expirationUnix: apnsExpirationUnix(),
      }),
      body: buildApnsPayload(input.record),
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

async function sendToDevice(input: {
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

  const host = apnsHostForEnvironment(input.environment);
  let lastRetryable = false;

  for (let attempt = 0; attempt < APNS_MAX_ATTEMPTS; attempt++) {
    const outcome = await sendOnce({
      host,
      token: input.token,
      topic: input.topic,
      record: input.record,
    });

    if (outcome.kind === "sent") return "sent";
    if (outcome.kind === "prune") {
      await pruneToken(input.supabase, input.userId, input.token);
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

  let payload: WebhookPayload;
  try {
    payload = await request.json() as WebhookPayload;
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
  try {
    supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  } catch (error) {
    console.error("Edge Function configuration error", error);
    return new Response("Server configuration error", { status: 500 });
  }
  const { data: devices, error } = await supabase
    .from("device_tokens")
    .select("token, environment")
    .eq("user_id", payload.record.user_id);
  if (error) {
    console.error("Could not load device tokens", error);
    return new Response("Could not load device tokens", { status: 500 });
  }
  if (!devices?.length) return Response.json({ sent: 0, failed: 0, retryable: 0 });

  let topic: string;
  try {
    await apnsJWT();
    topic = requiredEnv("APNS_TOPIC");
  } catch (error) {
    console.error("APNs configuration error", error);
    return new Response("Push service configuration error", { status: 500 });
  }

  const results = await Promise.all(devices.map(({ token, environment }) =>
    sendToDevice({
      supabase,
      userId: payload.record.user_id,
      token,
      environment,
      topic,
      record: payload.record,
    })
  ));

  const sent = results.filter((result) => result === "sent").length;
  const retryable = results.filter((result) => result === "retryable").length;
  const failed = results.length - sent - retryable;
  const status = webhookStatusForResults(retryable);

  return Response.json({ sent, failed, retryable }, { status });
});
