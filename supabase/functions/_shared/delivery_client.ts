import { createClient } from "https://esm.sh/@supabase/supabase-js@2.112.1";

export const DELIVERY_DATABASE_TIMEOUT_MS = 5_000;

/** Bound every delivery query, including response bodies and slot cleanup. */
export function createDeliveryClient(
  url: string,
  key: string,
  fetchImpl: typeof fetch = fetch,
  timeoutMs = DELIVERY_DATABASE_TIMEOUT_MS,
) {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    // SDK retries/backoff must not extend a database wait beyond its deadline.
    db: { retry: false },
    global: {
      fetch: (input, init) => {
        // Each request gets a fresh deadline, so an expired delivery request
        // cannot cancel the independent attempt to release its slot.
        const timeout = AbortSignal.timeout(timeoutMs);
        const previous = init?.signal ??
          (input instanceof Request ? input.signal : undefined);
        return fetchImpl(input, {
          ...init,
          signal: previous ? AbortSignal.any([previous, timeout]) : timeout,
        });
      },
    },
  });
}
