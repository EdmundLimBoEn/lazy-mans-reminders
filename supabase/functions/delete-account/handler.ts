import {
  maybeRevokeAppleTokens,
  userHasAppleIdentity,
} from "../_shared/apple_token_revoke.ts";
import {
  type GrantCleanupResult,
  revokeUserOauthGrants,
} from "../_shared/oauth_grant_cleanup.ts";

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export type DeleteAccountUser = {
  id: string;
  identities?: Array<{ provider?: string | null }> | null;
  app_metadata?: { providers?: unknown } | null;
};

export type DeleteAccountDeps = {
  env: (name: string) => string | undefined;
  fetchImpl: typeof fetch;
  nowSeconds: () => number;
  warn: (payload: Record<string, unknown>) => void;
  getUser: (
    authorization: string,
  ) => Promise<{ user: DeleteAccountUser | null }>;
  revokeGrants?: (input: {
    authorization: string;
    fetchImpl?: typeof fetch;
  }) => Promise<GrantCleanupResult>;
  deleteAuthUser: (userId: string) => Promise<{ error: unknown }>;
};

function jsonHeaders(): Record<string, string> {
  return corsHeaders;
}

async function readDeletionBody(
  request: Request,
): Promise<
  { appleAuthorizationCode?: string; expectedUserId?: string } | null
> {
  try {
    const text = await request.text();
    // Native clients intentionally send no body when no Apple code is needed.
    if (text === "") return {};
    const body = JSON.parse(text);
    if (
      !body || typeof body !== "object" || Array.isArray(body) ||
      (body.expectedUserId !== undefined &&
        typeof body.expectedUserId !== "string") ||
      (body.appleAuthorizationCode !== undefined &&
        typeof body.appleAuthorizationCode !== "string")
    ) return null;
    return body;
  } catch {
    return null;
  }
}

export async function handleDeleteAccount(
  request: Request,
  deps: DeleteAccountDeps,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { ...corsHeaders, allow: "POST" },
    });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  for (
    const name of [
      "SUPABASE_URL",
      "SUPABASE_ANON_KEY",
      "SUPABASE_SERVICE_ROLE_KEY",
    ]
  ) {
    if (!deps.env(name)?.trim()) {
      console.error("Edge Function configuration error", `Missing ${name}`);
      return new Response("Server configuration error", {
        status: 500,
        headers: corsHeaders,
      });
    }
  }

  const { user } = await deps.getUser(authHeader);
  if (!user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const body = await readDeletionBody(request);
  if (body === null) {
    return new Response("Invalid deletion request body", {
      status: 400,
      headers: corsHeaders,
    });
  }
  if (body.expectedUserId !== undefined && body.expectedUserId !== user.id) {
    return new Response(
      "Your signed-in account changed. Please reopen account deletion and try again.",
      { status: 409, headers: corsHeaders },
    );
  }
  const appleAuthorizationCode = typeof body.appleAuthorizationCode === "string"
    ? body.appleAuthorizationCode.trim() || undefined
    : undefined;
  let appleRevocation = userHasAppleIdentity(user)
    ? "manual_required"
    : "not_applicable";
  try {
    appleRevocation = await maybeRevokeAppleTokens({
      user,
      authorizationCode: appleAuthorizationCode,
      env: deps.env,
      fetchImpl: deps.fetchImpl,
      nowSeconds: deps.nowSeconds(),
      warn: deps.warn,
    });
  } catch {
    deps.warn({
      event: "apple_token_revoke",
      outcome: "failed",
      reason: "unexpected_error",
    });
  }

  const revokeGrants = deps.revokeGrants ?? revokeUserOauthGrants;
  const cleanup = await revokeGrants({
    authorization: authHeader,
    fetchImpl: deps.fetchImpl,
  });
  if (!cleanup.ok) {
    console.error("Could not revoke OAuth grants", cleanup.reason);
    return new Response("Could not revoke connected agents", {
      status: 503,
      headers: corsHeaders,
    });
  }

  // Auth-user cascades remove app data atomically and bypass exhausted write budgets.
  const { error: deleteError } = await deps.deleteAuthUser(user.id);
  if (deleteError) {
    console.error("Could not delete auth user", deleteError);
    return new Response("Could not delete account", {
      status: 500,
      headers: corsHeaders,
    });
  }

  return Response.json({
    ok: true,
    ...(appleRevocation !== "not_applicable" ? { appleRevocation } : {}),
  }, { headers: jsonHeaders() });
}
