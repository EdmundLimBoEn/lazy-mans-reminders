import { USER_DATA_TABLES } from "../_shared/account_tables.ts";
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
  deleteRows: (
    table: string,
    userId: string,
  ) => Promise<{ error: unknown }>;
  deleteAuthUser: (userId: string) => Promise<{ error: unknown }>;
};

function jsonHeaders(): Record<string, string> {
  return corsHeaders;
}

async function readAppleAuthorizationCode(
  request: Request,
): Promise<string | undefined> {
  try {
    const text = await request.text();
    if (!text.trim()) return undefined;
    const body = JSON.parse(text) as { appleAuthorizationCode?: unknown };
    if (typeof body.appleAuthorizationCode !== "string") return undefined;
    const code = body.appleAuthorizationCode.trim();
    return code.length > 0 ? code : undefined;
  } catch {
    return undefined;
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

  const appleAuthorizationCode = await readAppleAuthorizationCode(request);
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

  for (const table of USER_DATA_TABLES) {
    const { error: tableError } = await deps.deleteRows(table, user.id);
    if (tableError) {
      console.error(`Could not delete ${table}`, tableError);
      return new Response("Could not delete account data", {
        status: 500,
        headers: corsHeaders,
      });
    }
  }

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
