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
  const expiresAt = performance.now() + timeoutMs;
  const abortCleanup = () => {
    if (!controller.signal.aborted) {
      controller.abort();
      void reader?.cancel().catch(() => {});
    }
  };
  const expired = () => {
    if (performance.now() >= expiresAt) abortCleanup();
    return controller.signal.aborted;
  };
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<GrantCleanupResult>((resolve) => {
    timer = setTimeout(() => {
      abortCleanup();
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
    if (expired() || !response.ok) {
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
        // Ready chunks can starve the timer by keeping execution in microtasks.
        if (expired()) return { ok: false, reason: "unreachable" };
        const { done, value } = await reader.read();
        if (expired()) {
          return { ok: false, reason: "unreachable" };
        }
        if (done) break;
        text += decoder.decode(value, { stream: true });
      }
      text += decoder.decode();
      if (expired()) return { ok: false, reason: "unreachable" };
      const body = JSON.parse(text) as { complete?: unknown } | null;
      if (expired()) return { ok: false, reason: "unreachable" };
      return body?.complete === true
        ? { ok: true }
        : { ok: false, reason: "incomplete" };
    } catch {
      return {
        ok: false,
        reason: expired() ? "unreachable" : "incomplete",
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
