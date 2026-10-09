export const DEFAULT_GRANT_CLEANUP_URL =
  "https://lmr-mcp.edmundlim.systems/account/grants/cleanup";
export const DEFAULT_GRANT_CLEANUP_TIMEOUT_MS = 5_000;

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
  timeoutMs?: number;
}): Promise<GrantCleanupResult> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const url = input.cleanupUrl ?? Deno.env.get("MCP_GRANT_CLEANUP_URL") ??
    DEFAULT_GRANT_CLEANUP_URL;
  const controller = new AbortController();
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  const timeoutMs = input.timeoutMs ?? DEFAULT_GRANT_CLEANUP_TIMEOUT_MS;
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    return { ok: false, reason: "unreachable" };
  }
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<GrantCleanupResult>((resolve) => {
    timer = setTimeout(() => {
      controller.abort();
      void reader?.cancel().catch(() => {});
      resolve({ ok: false, reason: "unreachable" });
    }, timeoutMs);
  });
  const cleanup = async (): Promise<GrantCleanupResult> => {
    let response: Response;
    try {
      response = await fetchImpl(url, {
        method: "POST",
        headers: {
          Authorization: input.authorization,
          "Content-Type": "application/json",
        },
        body: "{}",
        signal: controller.signal,
      });
    } catch {
      return { ok: false, reason: "unreachable" };
    }
    if (controller.signal.aborted || !response.ok) {
      void response.body?.cancel().catch(() => {});
      return {
        ok: false,
        reason: controller.signal.aborted ? "unreachable" : "incomplete",
      };
    }
    try {
      reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let text = "";
      while (reader) {
        const { done, value } = await reader.read();
        if (controller.signal.aborted) {
          return { ok: false, reason: "unreachable" };
        }
        if (done) break;
        text += decoder.decode(value, { stream: true });
      }
      text += decoder.decode();
      const body = JSON.parse(text) as { complete?: unknown } | null;
      return body?.complete === true
        ? { ok: true }
        : { ok: false, reason: "incomplete" };
    } catch {
      return {
        ok: false,
        reason: controller.signal.aborted ? "unreachable" : "incomplete",
      };
    } finally {
      reader?.releaseLock();
    }
  };
  try {
    // Race also bounds injected transports that fail to honor the abort signal.
    return await Promise.race([cleanup(), deadline]);
  } finally {
    clearTimeout(timer);
  }
}
