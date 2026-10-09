import { base64url } from "./push_helpers.ts";

export const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
export const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
export const APPLE_AUDIENCE = "https://appleid.apple.com";
export const APPLE_CLIENT_SECRET_MAX_TTL_SECONDS = 15777000;
export const APPLE_CLIENT_SECRET_TTL_SECONDS = 60 * 60;

export const APPLE_SECRET_NAMES = [
  "APPLE_TEAM_ID",
  "APPLE_KEY_ID",
  "APPLE_PRIVATE_KEY",
  "APPLE_CLIENT_ID",
] as const;

export type AppleSecretName = (typeof APPLE_SECRET_NAMES)[number];

export type AppleSecretConfig = {
  teamId: string;
  keyId: string;
  privateKey: string;
  clientId: string;
};

export type AppleRevokeWarning = {
  event: "apple_token_revoke";
  outcome: "skipped" | "failed";
  reason: string;
  missing?: string[];
  status?: number;
  endpoint?: "token" | "revoke";
  appleError?: string;
};

export type AppleRevokeResult =
  | { ok: true; tokenType: "refresh_token" | "access_token" }
  | { ok: false; warning: AppleRevokeWarning };

const encoder = new TextEncoder();

function nonempty(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function userHasAppleIdentity(user: {
  identities?: Array<{ provider?: string | null }> | null;
  app_metadata?: { providers?: unknown } | null;
}): boolean {
  const fromIdentities = (user.identities ?? []).some(
    (identity) => identity.provider?.toLowerCase() === "apple",
  );
  if (fromIdentities) return true;
  const providers = user.app_metadata?.providers;
  return Array.isArray(providers) &&
    providers.some((provider) => String(provider).toLowerCase() === "apple");
}

export function readAppleSecrets(
  env: (name: string) => string | undefined,
):
  | { ok: true; config: AppleSecretConfig }
  | { ok: false; missing: AppleSecretName[] } {
  const teamId = nonempty(env("APPLE_TEAM_ID"));
  const keyId = nonempty(env("APPLE_KEY_ID"));
  const privateKey = nonempty(env("APPLE_PRIVATE_KEY"));
  const clientId = nonempty(env("APPLE_CLIENT_ID"));
  const missing: AppleSecretName[] = [];
  if (!teamId) missing.push("APPLE_TEAM_ID");
  if (!keyId) missing.push("APPLE_KEY_ID");
  if (!privateKey) missing.push("APPLE_PRIVATE_KEY");
  if (!clientId) missing.push("APPLE_CLIENT_ID");
  if (missing.length > 0) return { ok: false, missing };
  return {
    ok: true,
    config: {
      teamId: teamId!,
      keyId: keyId!,
      privateKey: privateKey!,
      clientId: clientId!,
    },
  };
}

function pemToPkcs8(pem: string): Uint8Array<ArrayBuffer> {
  const normalized = pem.replaceAll("\\n", "\n");
  const body = normalized.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    "",
  );
  if (!body) throw new Error("APPLE_PRIVATE_KEY is not a valid PKCS#8 PEM key");
  const bytes = Uint8Array.from(
    atob(body),
    (character) => character.charCodeAt(0),
  );
  return new Uint8Array(bytes);
}

export async function mintAppleClientSecret(input: {
  config: AppleSecretConfig;
  nowSeconds: number;
  ttlSeconds?: number;
}): Promise<string> {
  const ttl = Math.min(
    input.ttlSeconds ?? APPLE_CLIENT_SECRET_TTL_SECONDS,
    APPLE_CLIENT_SECRET_MAX_TTL_SECONDS,
  );
  if (ttl <= 0) throw new Error("Apple client secret TTL must be positive");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(input.config.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64url(
    JSON.stringify({ alg: "ES256", kid: input.config.keyId }),
  );
  const claims = base64url(
    JSON.stringify({
      iss: input.config.teamId,
      iat: input.nowSeconds,
      exp: input.nowSeconds + ttl,
      aud: APPLE_AUDIENCE,
      sub: input.config.clientId,
    }),
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
      `Unexpected Apple ES256 signature length: ${signature.length}`,
    );
  }
  return `${unsigned}.${base64url(signature)}`;
}

function formBody(fields: Record<string, string>): string {
  return new URLSearchParams(fields).toString();
}

async function postAppleForm(input: {
  url: string;
  fields: Record<string, string>;
  fetchImpl: typeof fetch;
}): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5_000);
  try {
    const response = await input.fetchImpl(input.url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: formBody(input.fields),
      signal: controller.signal,
    });
    // Keep the deadline active while reading Apple's response body too.
    const body = await response.text();
    return new Response(body || null, {
      status: response.status,
      headers: response.headers,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function appleErrorMessage(
  response: Response,
): Promise<string | undefined> {
  try {
    const body = await response.json() as { error?: unknown };
    return typeof body.error === "string" ? body.error : undefined;
  } catch {
    return undefined;
  }
}

export async function revokeAppleTokensWithAuthorizationCode(input: {
  authorizationCode: string;
  config: AppleSecretConfig;
  fetchImpl: typeof fetch;
  nowSeconds: number;
}): Promise<AppleRevokeResult> {
  let clientSecret: string;
  try {
    clientSecret = await mintAppleClientSecret({
      config: input.config,
      nowSeconds: input.nowSeconds,
    });
  } catch {
    return {
      ok: false,
      warning: {
        event: "apple_token_revoke",
        outcome: "failed",
        reason: "client_secret_error",
      },
    };
  }

  const tokenResponse = await postAppleForm({
    url: APPLE_TOKEN_URL,
    fetchImpl: input.fetchImpl,
    fields: {
      client_id: input.config.clientId,
      client_secret: clientSecret,
      code: input.authorizationCode,
      grant_type: "authorization_code",
    },
  });
  if (!tokenResponse.ok) {
    return {
      ok: false,
      warning: {
        event: "apple_token_revoke",
        outcome: "failed",
        reason: "apple_http_error",
        status: tokenResponse.status,
        endpoint: "token",
        appleError: await appleErrorMessage(tokenResponse),
      },
    };
  }

  let tokens: { refresh_token?: unknown; access_token?: unknown };
  try {
    tokens = await tokenResponse.json() as {
      refresh_token?: unknown;
      access_token?: unknown;
    };
  } catch {
    return {
      ok: false,
      warning: {
        event: "apple_token_revoke",
        outcome: "failed",
        reason: "apple_token_response_invalid",
        endpoint: "token",
      },
    };
  }

  const refreshToken = nonempty(
    typeof tokens.refresh_token === "string" ? tokens.refresh_token : undefined,
  );
  const accessToken = nonempty(
    typeof tokens.access_token === "string" ? tokens.access_token : undefined,
  );
  const tokenType = refreshToken ? "refresh_token" : "access_token";
  const token = refreshToken ?? accessToken;
  if (!token) {
    return {
      ok: false,
      warning: {
        event: "apple_token_revoke",
        outcome: "failed",
        reason: "apple_tokens_missing",
        endpoint: "token",
      },
    };
  }

  // Revocation is idempotent; retry the same token, never the single-use code.
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 250));
    }
    let revokeResponse: Response;
    try {
      revokeResponse = await postAppleForm({
        url: APPLE_REVOKE_URL,
        fetchImpl: input.fetchImpl,
        fields: {
          client_id: input.config.clientId,
          client_secret: clientSecret,
          token,
          token_type_hint: tokenType,
        },
      });
    } catch {
      if (attempt < 2) continue;
      return {
        ok: false,
        warning: {
          event: "apple_token_revoke",
          outcome: "failed",
          reason: "apple_network_error",
          endpoint: "revoke",
        },
      };
    }
    if (revokeResponse.ok) return { ok: true, tokenType };
    if (
      attempt < 2 &&
      (revokeResponse.status === 429 || revokeResponse.status >= 500)
    ) continue;
    return {
      ok: false,
      warning: {
        event: "apple_token_revoke",
        outcome: "failed",
        reason: "apple_http_error",
        status: revokeResponse.status,
        endpoint: "revoke",
        appleError: await appleErrorMessage(revokeResponse),
      },
    };
  }

  return { ok: true, tokenType };
}

export async function maybeRevokeAppleTokens(input: {
  user: Parameters<typeof userHasAppleIdentity>[0];
  authorizationCode: string | undefined;
  env: (name: string) => string | undefined;
  fetchImpl: typeof fetch;
  nowSeconds: number;
  warn: (warning: AppleRevokeWarning) => void;
}): Promise<"not_applicable" | "revoked" | "manual_required"> {
  if (!userHasAppleIdentity(input.user)) return "not_applicable";

  if (!input.authorizationCode) {
    input.warn({
      event: "apple_token_revoke",
      outcome: "skipped",
      reason: "no_authorization_code",
    });
    return "manual_required";
  }

  const secrets = readAppleSecrets(input.env);
  if (!secrets.ok) {
    input.warn({
      event: "apple_token_revoke",
      outcome: "skipped",
      reason: "missing_secrets",
      missing: secrets.missing,
    });
    return "manual_required";
  }

  const result = await revokeAppleTokensWithAuthorizationCode({
    authorizationCode: input.authorizationCode,
    config: secrets.config,
    fetchImpl: input.fetchImpl,
    nowSeconds: input.nowSeconds,
  });
  if (!result.ok) input.warn(result.warning);
  return result.ok ? "revoked" : "manual_required";
}
