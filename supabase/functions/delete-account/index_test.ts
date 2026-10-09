import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { USER_DATA_TABLES } from "../_shared/account_tables.ts";
import {
  APPLE_AUDIENCE,
  APPLE_CLIENT_SECRET_MAX_TTL_SECONDS,
  APPLE_REVOKE_URL,
  APPLE_TOKEN_URL,
  mintAppleClientSecret,
} from "../_shared/apple_token_revoke.ts";
import {
  type DeleteAccountDeps,
  type DeleteAccountUser,
  handleDeleteAccount,
} from "./handler.ts";

const TEST_P256_PKCS8 = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgSgeLQ0cR6baPkocl
/Bn1F2PFdq0Vo/tI8qb5R3bBft2hRANCAATr7IIDJQ+sWtH91oiDZG+a9CyGC7LU
3d85+GBh9tRijHXF1qV2gNx6ghjmMlknjc1qvwtJAZo0zy4ELEqhkxV5
-----END PRIVATE KEY-----`;

const NOW_SECONDS = 1_700_000_000;
const APPLE_CLIENT_ID = "systems.edmundlim.LazyMansReminders";
const APPLE_TEAM_ID = "TEAMID1234";
const APPLE_KEY_ID = "KEYID12345";
const appleUser: DeleteAccountUser = {
  id: "11111111-1111-4111-8111-111111111111",
  identities: [{ provider: "apple" }],
};

const googleUser: DeleteAccountUser = {
  id: "22222222-2222-4222-8222-222222222222",
  identities: [{ provider: "google" }],
};

type AppleCall = {
  url: string;
  body: string;
  contentType: string | null;
};

function supabaseEnv(): Record<string, string> {
  return {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "anon",
    SUPABASE_SERVICE_ROLE_KEY: "service",
  };
}

function appleEnv(): Record<string, string> {
  return {
    ...supabaseEnv(),
    APPLE_TEAM_ID,
    APPLE_KEY_ID,
    APPLE_CLIENT_ID,
    APPLE_PRIVATE_KEY: TEST_P256_PKCS8,
  };
}

function decodeJwt(
  jwt: string,
): { header: Record<string, unknown>; payload: Record<string, unknown> } {
  const [headerPart, payloadPart] = jwt.split(".");
  const decode = (part: string) => {
    const padded = part.replaceAll("-", "+").replaceAll("_", "/");
    const pad = "=".repeat((4 - padded.length % 4) % 4);
    return JSON.parse(atob(padded + pad)) as Record<string, unknown>;
  };
  return { header: decode(headerPart), payload: decode(payloadPart) };
}

function form(body: string): Record<string, string> {
  return Object.fromEntries(new URLSearchParams(body));
}

async function runDelete(input: {
  user: DeleteAccountUser | null;
  body?: unknown;
  env?: Record<string, string | undefined>;
  token?: Response | ((body: string) => Response);
  revoke?: Response | ((body: string) => Response);
  grants?: { ok: false; reason: "incomplete" | "unreachable" };
  failedTable?: string;
  authError?: unknown;
  throwToken?: boolean;
  hangToken?: boolean;
}): Promise<{
  response: Response;
  appleCalls: AppleCall[];
  warnings: Record<string, unknown>[];
  deletedTables: string[];
  deletedUserId: string | null;
}> {
  const appleCalls: AppleCall[] = [];
  const warnings: Record<string, unknown>[] = [];
  const deletedTables: string[] = [];
  let deletedUserId: string | null = null;
  const envMap = input.env ?? appleEnv();

  const fetchImpl: typeof fetch = (requestUrl, init) => {
    const url = String(requestUrl);
    const headers = new Headers(init?.headers);
    const body = typeof init?.body === "string" ? init.body : "";
    if (url.startsWith("https://appleid.apple.com/")) {
      appleCalls.push({
        url,
        body,
        contentType: headers.get("content-type"),
      });
      if (url === APPLE_TOKEN_URL) {
        if (input.hangToken) {
          return new Promise((_resolve, reject) => {
            init?.signal?.addEventListener(
              "abort",
              () => reject(new DOMException("Timed out", "AbortError")),
              { once: true },
            );
          });
        }
        if (input.throwToken) return Promise.reject(new Error("network down"));
        const token = input.token ??
          Response.json({
            access_token: "access-token",
            refresh_token: "refresh-token",
          });
        return Promise.resolve(
          typeof token === "function" ? token(body) : token,
        );
      }
      if (url === APPLE_REVOKE_URL) {
        const revoke = input.revoke ?? new Response(null, { status: 200 });
        return Promise.resolve(
          typeof revoke === "function" ? revoke(body) : revoke,
        );
      }
      return Promise.resolve(
        new Response("unexpected apple url", { status: 500 }),
      );
    }
    return Promise.resolve(new Response("unexpected url", { status: 500 }));
  };

  const deps: DeleteAccountDeps = {
    env: (name) => envMap[name],
    fetchImpl,
    nowSeconds: () => NOW_SECONDS,
    warn: (payload) => warnings.push(payload),
    getUser: () => Promise.resolve({ user: input.user }),
    revokeGrants: () => Promise.resolve(input.grants ?? { ok: true }),
    deleteRows: (table, _userId) => {
      deletedTables.push(table);
      return Promise.resolve({
        error: table === input.failedTable ? "failed" : null,
      });
    },
    deleteAuthUser: (userId) => {
      if (!input.authError) deletedUserId = userId;
      return Promise.resolve({ error: input.authError ?? null });
    },
  };

  const headers: Record<string, string> = {
    Authorization: "Bearer user-jwt",
  };
  let requestBody: string | undefined;
  if (input.body !== undefined) {
    headers["Content-Type"] = "application/json";
    requestBody = JSON.stringify(input.body);
  }

  const response = await handleDeleteAccount(
    new Request("https://example.supabase.co/functions/v1/delete-account", {
      method: "POST",
      headers,
      body: requestBody,
    }),
    deps,
  );

  return { response, appleCalls, warnings, deletedTables, deletedUserId };
}

async function assertDeleted(
  result: Awaited<ReturnType<typeof runDelete>>,
  userId: string,
) {
  assertEquals(result.response.status, 200);
  const body = await result.response.json();
  assertEquals(body.ok, true);
  if (userId === appleUser.id) {
    assertEquals(
      body.appleRevocation,
      result.warnings.length ? "manual_required" : "revoked",
    );
  } else {
    assertEquals(body.appleRevocation, undefined);
  }
  assertEquals(result.deletedTables, [...USER_DATA_TABLES]);
  assertEquals(result.deletedUserId, userId);
}

Deno.test("Apple client secret JWT uses ES256 claims Apple requires", async () => {
  const jwt = await mintAppleClientSecret({
    config: {
      teamId: APPLE_TEAM_ID,
      keyId: APPLE_KEY_ID,
      privateKey: TEST_P256_PKCS8,
      clientId: APPLE_CLIENT_ID,
    },
    nowSeconds: NOW_SECONDS,
  });
  const { header, payload } = decodeJwt(jwt);
  assertEquals(header.alg, "ES256");
  assertEquals(header.kid, APPLE_KEY_ID);
  assertEquals(payload.iss, APPLE_TEAM_ID);
  assertEquals(payload.aud, APPLE_AUDIENCE);
  assertEquals(payload.sub, APPLE_CLIENT_ID);
  assertEquals(payload.iat, NOW_SECONDS);
  assertEquals(typeof payload.exp, "number");
  const exp = payload.exp as number;
  assertEquals(exp > NOW_SECONDS, true);
  assertEquals(exp - NOW_SECONDS <= APPLE_CLIENT_SECRET_MAX_TTL_SECONDS, true);
});

Deno.test("Apple users exchange the authorization code then revoke the refresh token", async () => {
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "auth-code-from-ios" },
  });
  await assertDeleted(result, appleUser.id);
  assertEquals(result.warnings, []);
  assertEquals(result.appleCalls.map((call) => call.url), [
    APPLE_TOKEN_URL,
    APPLE_REVOKE_URL,
  ]);

  const tokenCall = result.appleCalls[0];
  assertEquals(tokenCall.contentType, "application/x-www-form-urlencoded");
  const tokenForm = form(tokenCall.body);
  assertEquals(tokenForm.client_id, APPLE_CLIENT_ID);
  assertEquals(tokenForm.code, "auth-code-from-ios");
  assertEquals(tokenForm.grant_type, "authorization_code");
  assertExists(tokenForm.client_secret);
  const { header, payload } = decodeJwt(tokenForm.client_secret);
  assertEquals(header.alg, "ES256");
  assertEquals(header.kid, APPLE_KEY_ID);
  assertEquals(payload.iss, APPLE_TEAM_ID);
  assertEquals(payload.aud, APPLE_AUDIENCE);
  assertEquals(payload.sub, APPLE_CLIENT_ID);
  assertEquals(payload.iat, NOW_SECONDS);
  const exp = payload.exp as number;
  assertEquals(exp - NOW_SECONDS <= APPLE_CLIENT_SECRET_MAX_TTL_SECONDS, true);

  const revokeCall = result.appleCalls[1];
  assertEquals(revokeCall.contentType, "application/x-www-form-urlencoded");
  const revokeForm = form(revokeCall.body);
  assertEquals(revokeForm.client_id, APPLE_CLIENT_ID);
  assertEquals(revokeForm.token, "refresh-token");
  assertEquals(revokeForm.token_type_hint, "refresh_token");
  assertEquals(revokeForm.client_secret, tokenForm.client_secret);
});

Deno.test("Apple revoke falls back to the access token when no refresh token is returned", async () => {
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "auth-code-from-ios" },
    token: Response.json({ access_token: "only-access" }),
  });
  await assertDeleted(result, appleUser.id);
  const revokeForm = form(result.appleCalls[1].body);
  assertEquals(revokeForm.token, "only-access");
  assertEquals(revokeForm.token_type_hint, "access_token");
});

Deno.test("Apple HTTP 400 still deletes the account", async () => {
  const tokenFailure = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "auth-code-from-ios" },
    token: Response.json({ error: "invalid_grant" }, { status: 400 }),
  });
  await assertDeleted(tokenFailure, appleUser.id);
  assertEquals(tokenFailure.warnings[0], {
    event: "apple_token_revoke",
    outcome: "failed",
    reason: "apple_http_error",
    status: 400,
    endpoint: "token",
    appleError: "invalid_grant",
  });
  assertEquals(tokenFailure.appleCalls.map((call) => call.url), [
    APPLE_TOKEN_URL,
  ]);

  const revokeFailure = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "auth-code-from-ios" },
    revoke: Response.json({ error: "invalid_request" }, { status: 400 }),
  });
  await assertDeleted(revokeFailure, appleUser.id);
  assertEquals(revokeFailure.warnings[0]?.endpoint, "revoke");
  assertEquals(revokeFailure.warnings[0]?.status, 400);
  assertEquals(revokeFailure.deletedUserId, appleUser.id);
});

Deno.test("missing Apple secrets still delete the account", async () => {
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "auth-code-from-ios" },
    env: supabaseEnv(),
  });
  await assertDeleted(result, appleUser.id);
  assertEquals(result.appleCalls, []);
  assertEquals(result.warnings[0], {
    event: "apple_token_revoke",
    outcome: "skipped",
    reason: "missing_secrets",
    missing: [
      "APPLE_TEAM_ID",
      "APPLE_KEY_ID",
      "APPLE_PRIVATE_KEY",
      "APPLE_CLIENT_ID",
    ],
  });
});

Deno.test("non-Apple users skip token revocation", async () => {
  const result = await runDelete({
    user: googleUser,
    body: { appleAuthorizationCode: "should-be-ignored" },
  });
  await assertDeleted(result, googleUser.id);
  assertEquals(result.appleCalls, []);
  assertEquals(result.warnings, []);
});

Deno.test("Apple users without an authorization code skip revocation and still delete", async () => {
  const result = await runDelete({ user: appleUser });
  await assertDeleted(result, appleUser.id);
  assertEquals(result.appleCalls, []);
  assertEquals(result.warnings[0], {
    event: "apple_token_revoke",
    outcome: "skipped",
    reason: "no_authorization_code",
  });
});

Deno.test("transient revocation failures retry the same refresh token without reusing the code", async () => {
  let attempts = 0;
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "single-use-code" },
    revoke: () =>
      ++attempts < 3 ? new Response(null, { status: 503 }) : new Response(null),
  });
  await assertDeleted(result, appleUser.id);
  assertEquals(result.appleCalls.map((call) => call.url), [
    APPLE_TOKEN_URL,
    APPLE_REVOKE_URL,
    APPLE_REVOKE_URL,
    APPLE_REVOKE_URL,
  ]);
  assertEquals(
    result.appleCalls.slice(1).map((call) => form(call.body).token),
    ["refresh-token", "refresh-token", "refresh-token"],
  );
});

Deno.test("revocation network failure recovers with the exchanged token", async () => {
  let attempts = 0;
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "code" },
    revoke: () => {
      if (++attempts === 1) throw new Error("network down");
      return new Response(null);
    },
  });
  await assertDeleted(result, appleUser.id);
  assertEquals(attempts, 2);
});

Deno.test("exhausted revocation retries and code exchange outages preserve deletion with manual guidance", async () => {
  for (const throwToken of [false, true]) {
    const result = await runDelete({
      user: appleUser,
      body: { appleAuthorizationCode: "code" },
      throwToken,
      revoke: () => new Response(null, { status: 503 }),
    });
    await assertDeleted(result, appleUser.id);
    assertEquals(result.appleCalls.length, throwToken ? 1 : 4);
    assertEquals(result.warnings.length, 1);
    assertEquals(
      JSON.stringify(result.warnings).includes("refresh-token"),
      false,
    );
  }
});

Deno.test("OAuth cleanup failure stops before deleting app data or auth", async () => {
  for (const reason of ["incomplete", "unreachable"] as const) {
    const result = await runDelete({
      user: googleUser,
      grants: { ok: false, reason },
    });
    assertEquals(result.response.status, 503);
    assertEquals(result.deletedTables, []);
    assertEquals(result.deletedUserId, null);
  }
});

Deno.test("data and auth deletion failures never report success", async () => {
  const tableFailure = await runDelete({
    user: googleUser,
    failedTable: USER_DATA_TABLES[0],
  });
  assertEquals(tableFailure.response.status, 500);
  assertEquals(tableFailure.deletedTables, [USER_DATA_TABLES[0]]);
  assertEquals(tableFailure.deletedUserId, null);
  const authFailure = await runDelete({
    user: googleUser,
    authError: "failed",
  });
  assertEquals(authFailure.response.status, 500);
  assertEquals(authFailure.deletedTables, [...USER_DATA_TABLES]);
  assertEquals(authFailure.deletedUserId, null);
});

Deno.test("an unresponsive Apple exchange times out without blocking deletion", async () => {
  const result = await runDelete({
    user: appleUser,
    body: { appleAuthorizationCode: "code" },
    hangToken: true,
  });
  await assertDeleted(result, appleUser.id);
  assertEquals(result.appleCalls.length, 1);
  assertEquals(result.warnings.length, 1);
});

Deno.test("unauthenticated requests cannot revoke Apple credentials or delete data", async () => {
  const result = await runDelete({
    user: null,
    body: { appleAuthorizationCode: "code" },
  });
  assertEquals(result.response.status, 401);
  assertEquals(result.appleCalls, []);
  assertEquals(result.deletedTables, []);
  assertEquals(result.deletedUserId, null);
});
