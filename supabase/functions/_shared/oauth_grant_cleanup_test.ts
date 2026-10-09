import { assertEquals, assertExists } from "jsr:@std/assert";
import { handleDeleteAccount } from "../delete-account/handler.ts";
import {
  DEFAULT_GRANT_CLEANUP_TIMEOUT_MS,
  revokeUserOauthGrants,
} from "./oauth_grant_cleanup.ts";

const input = {
  authorization: "Bearer user-jwt",
  cleanupUrl: "https://mcp.example/account/grants/cleanup",
};

Deno.test("grant cleanup sends authenticated POST and accepts a complete report", async () => {
  let signal: AbortSignal | undefined;
  const result = await revokeUserOauthGrants({
    ...input,
    fetchImpl: (url, init) => {
      assertEquals(url, input.cleanupUrl);
      assertEquals(init?.method, "POST");
      assertEquals(
        new Headers(init?.headers).get("Authorization"),
        input.authorization,
      );
      assertEquals(
        new Headers(init?.headers).get("Content-Type"),
        "application/json",
      );
      assertEquals(init?.body, "{}");
      signal = init?.signal ?? undefined;
      return Promise.resolve(
        Response.json({ complete: true, revoked: 1, failed: 0, remaining: 0 }),
      );
    },
  });
  assertEquals(result, { ok: true });
  assertExists(signal);
  assertEquals(signal.aborted, false);
  assertEquals(DEFAULT_GRANT_CLEANUP_TIMEOUT_MS, 5_000);
});

Deno.test("grant cleanup fails closed for malformed or incomplete reports", async () => {
  for (
    const report of [
      "{",
      "null",
      "{}",
      '{"complete":false}',
      '{"complete":"true"}',
      "[]",
    ]
  ) {
    const result = await revokeUserOauthGrants({
      ...input,
      fetchImpl: () => Promise.resolve(new Response(report)),
    });
    assertEquals(result, { ok: false, reason: "incomplete" }, report);
  }
});

Deno.test("grant cleanup cancels an unsuccessful response body", async () => {
  let cancelled = false;
  const result = await revokeUserOauthGrants({
    ...input,
    fetchImpl: () =>
      Promise.resolve(
        new Response(
          new ReadableStream({
            cancel() {
              cancelled = true;
            },
          }),
          { status: 503 },
        ),
      ),
  });
  assertEquals(result, { ok: false, reason: "incomplete" });
  assertEquals(cancelled, true);
});

Deno.test("grant cleanup fails closed when the worker cannot be reached", async () => {
  const result = await revokeUserOauthGrants({
    ...input,
    fetchImpl: () => Promise.reject(new Error("offline")),
  });
  assertEquals(result, { ok: false, reason: "unreachable" });
});

Deno.test("grant cleanup aborts a never-responsive fetch at its deadline", async () => {
  let signal: AbortSignal | undefined;
  let aborted = false;
  const result = await revokeUserOauthGrants({
    ...input,
    timeoutMs: 10,
    fetchImpl: (_url, init) =>
      new Promise((_resolve, reject) => {
        signal = init?.signal ?? undefined;
        assertExists(signal);
        signal.addEventListener("abort", () => {
          aborted = true;
          reject(signal?.reason);
        }, { once: true });
      }),
  });
  assertEquals(result, { ok: false, reason: "unreachable" });
  assertEquals(signal?.aborted, true);
  assertEquals(aborted, true);
});

Deno.test("grant cleanup bounds a transport ignoring abort and cancels its late response", async () => {
  let resolveFetch!: (response: Response) => void;
  let cancelled = false;
  const pending = revokeUserOauthGrants({
    ...input,
    timeoutMs: 10,
    fetchImpl: () =>
      new Promise((resolve) => {
        resolveFetch = resolve;
      }),
  });
  assertEquals(await pending, { ok: false, reason: "unreachable" });
  resolveFetch(
    new Response(
      new ReadableStream({
        cancel() {
          cancelled = true;
        },
      }),
    ),
  );
  await Promise.resolve();
  assertEquals(cancelled, true);
});

Deno.test("grant cleanup deadline covers a stalled body and cancels its reader", async () => {
  let cancelled = false;
  let signal: AbortSignal | undefined;
  const response = new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new TextEncoder().encode('{"complete":'));
      },
      cancel() {
        cancelled = true;
      },
    }),
  );
  const result = await revokeUserOauthGrants({
    ...input,
    timeoutMs: 10,
    fetchImpl: (_url, init) => {
      signal = init?.signal ?? undefined;
      return Promise.resolve(response);
    },
  });
  assertEquals(result, { ok: false, reason: "unreachable" });
  assertEquals(signal?.aborted, true);
  assertEquals(cancelled, true);
  assertEquals(response.body?.locked, false);
});

Deno.test("grant cleanup decodes JSON split across streamed chunks", async () => {
  const response = new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        const bytes = new TextEncoder().encode('{"label":"é","complete":true}');
        for (const byte of bytes) controller.enqueue(Uint8Array.of(byte));
        controller.close();
      },
    }),
  );
  assertEquals(
    await revokeUserOauthGrants({
      ...input,
      fetchImpl: () => Promise.resolve(response),
    }),
    { ok: true },
  );
  assertEquals(response.body?.locked, false);
});

Deno.test("grant cleanup aborts continuously ready chunks even when the timer is starved", async () => {
  let cancelled = false;
  let completed = false;
  let signal: AbortSignal | undefined;
  const encoder = new TextEncoder();
  const padding = encoder.encode("                ");
  let finishAt = 0;
  const response = new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(encoder.encode('{"complete":true'));
      },
      pull(controller) {
        if (performance.now() < finishAt) {
          controller.enqueue(padding);
        } else {
          completed = true;
          controller.enqueue(encoder.encode("}"));
          controller.close();
        }
      },
      cancel() {
        cancelled = true;
      },
    }),
  );
  const result = await revokeUserOauthGrants({
    ...input,
    timeoutMs: 10,
    fetchImpl: (_url, init) => {
      signal = init?.signal ?? undefined;
      // The finite producer stays ready beyond the deadline without yielding to timers.
      finishAt = performance.now() + 30;
      return Promise.resolve(response);
    },
  });
  assertEquals(result, { ok: false, reason: "unreachable" });
  assertEquals(signal?.aborted, true);
  assertEquals(cancelled, true);
  assertEquals(completed, false);
  assertEquals(response.body?.locked, false);
});

Deno.test("grant cleanup rejects invalid deadlines without sending a request", async () => {
  for (const timeoutMs of [0, -1, NaN, Infinity]) {
    assertEquals(
      await revokeUserOauthGrants({
        ...input,
        timeoutMs,
        fetchImpl: () => {
          throw new Error("must not fetch");
        },
      }),
      { ok: false, reason: "unreachable" },
    );
  }
});

Deno.test("cleanup timeouts prevent both account data and auth user deletion", async () => {
  for (const phase of ["fetch", "body"]) {
    let deletions = 0;
    const fetchImpl: typeof fetch = (_url, init) => {
      if (phase === "fetch") {
        return new Promise((_resolve, reject) => {
          init?.signal?.addEventListener(
            "abort",
            () => reject(new Error("aborted")),
            {
              once: true,
            },
          );
        });
      }
      return Promise.resolve(new Response(new ReadableStream<Uint8Array>()));
    };
    const response = await handleDeleteAccount(
      new Request("https://example.supabase.co/functions/v1/delete-account", {
        method: "POST",
        headers: { Authorization: input.authorization },
      }),
      {
        env: () => "test-config",
        fetchImpl,
        nowSeconds: () => 1_700_000_000,
        warn: () => {},
        getUser: () => Promise.resolve({ user: { id: "test-user" } }),
        revokeGrants: (request) =>
          revokeUserOauthGrants({
            ...request,
            cleanupUrl: input.cleanupUrl,
            timeoutMs: 10,
          }),
        deleteRows: () => {
          deletions++;
          return Promise.resolve({ error: null });
        },
        deleteAuthUser: () => {
          deletions++;
          return Promise.resolve({ error: null });
        },
      },
    );
    assertEquals(response.status, 503, phase);
    assertEquals(await response.text(), "Could not revoke connected agents");
    assertEquals(deletions, 0, phase);
  }
});
