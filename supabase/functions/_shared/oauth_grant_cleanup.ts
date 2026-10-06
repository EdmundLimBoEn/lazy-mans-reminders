export const DEFAULT_GRANT_CLEANUP_URL =
  "https://lmr-mcp.edmundlim.systems/account/grants/cleanup";

export type GrantCleanupResult =
  | { ok: true }
  | { ok: false; reason: "incomplete" | "unreachable" };

/**
 * Ask the Worker to revoke this user's OAuth grants. Anything other than
 * `complete: true` is a failure, so account deletion can stop before it
 * removes the auth user.
 */
export async function revokeUserOauthGrants(input: {
  authorization: string;
  cleanupUrl?: string;
  fetchImpl?: typeof fetch;
}): Promise<GrantCleanupResult> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const url = input.cleanupUrl ?? Deno.env.get("MCP_GRANT_CLEANUP_URL") ??
    DEFAULT_GRANT_CLEANUP_URL;
  let response: Response;
  try {
    response = await fetchImpl(url, {
      method: "POST",
      headers: {
        Authorization: input.authorization,
        "Content-Type": "application/json",
      },
      body: "{}",
    });
  } catch {
    return { ok: false, reason: "unreachable" };
  }
  if (!response.ok) return { ok: false, reason: "incomplete" };
  try {
    const body = await response.json() as { complete?: unknown };
    return body.complete === true
      ? { ok: true }
      : { ok: false, reason: "incomplete" };
  } catch {
    return { ok: false, reason: "incomplete" };
  }
}
