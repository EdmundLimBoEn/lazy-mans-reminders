import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ReminderRecord = {
  id: string;
  user_id: string;
  text: string;
};

type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: ReminderRecord;
};

const encoder = new TextEncoder();
const APNS_TOKEN_PATTERN = /^[0-9a-f]{64}$/i;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const APNS_JWT_TTL_MS = 50 * 60 * 1000;

let cachedAPNSJWT: { value: string; createdAt: number } | undefined;

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? encoder.encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
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

  if (
    payload.type !== "INSERT" ||
    payload.table !== "reminders" ||
    payload.schema !== "public"
  ) {
    return new Response("Ignored", { status: 202 });
  }
  if (
    !payload.record ||
    !UUID_PATTERN.test(payload.record.id) ||
    !UUID_PATTERN.test(payload.record.user_id) ||
    typeof payload.record.text !== "string" ||
    payload.record.text.length === 0 ||
    payload.record.text.length > 500
  ) {
    return new Response("Invalid webhook payload", { status: 400 });
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
  if (!devices?.length) return Response.json({ sent: 0 });

  let jwt: string;
  let topic: string;
  try {
    jwt = await apnsJWT();
    topic = requiredEnv("APNS_TOPIC");
  } catch (error) {
    console.error("APNs configuration error", error);
    return new Response("Push service configuration error", { status: 500 });
  }

  let sent = 0;
  let failed = 0;

  await Promise.all(devices.map(async ({ token, environment }) => {
    if (!APNS_TOKEN_PATTERN.test(token)) {
      failed += 1;
      console.error("Skipping malformed APNs token");
      return;
    }

    const host = environment === "development"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";
    try {
      const response = await fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "content-type": "application/json",
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: {
            alert: { title: "New reminder", body: payload.record.text },
            sound: "default",
            "content-available": 1,
          },
          reminder_id: payload.record.id,
        }),
      });
      if (response.ok) {
        sent += 1;
      } else {
        failed += 1;
        const responseBody = await response.text();
        if (response.status === 410) {
          const { error: deleteError } = await supabase
            .from("device_tokens")
            .delete()
            .eq("token", token)
            .eq("user_id", payload.record.user_id);
          if (deleteError) {
            console.error("Could not remove expired APNs token", deleteError);
          }
        }
        console.error("APNs rejected push", response.status, responseBody);
      }
    } catch (error) {
      failed += 1;
      console.error("APNs request failed", error);
    }
  }));

  return Response.json({ sent, failed });
});
