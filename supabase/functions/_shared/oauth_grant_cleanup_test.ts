import { assertEquals } from "jsr:@std/assert";
import { revokeUserOauthGrants } from "./oauth_grant_cleanup.ts";

Deno.test("grant cleanup accepts only a complete report", async () => {
  const ok = await revokeUserOauthGrants({
    authorization: "Bearer user-jwt",
    cleanupUrl: "https://mcp.example/account/grants/cleanup",
    fetchImpl: () =>
      Promise.resolve(Response.json({ complete: true, revoked: 1, failed: 0, remaining: 0 })),
  });
  assertEquals(ok, { ok: true });

  const incomplete = await revokeUserOauthGrants({
    authorization: "Bearer user-jwt",
    cleanupUrl: "https://mcp.example/account/grants/cleanup",
    fetchImpl: () =>
      Promise.resolve(new Response(JSON.stringify({ complete: false, remaining: 1 }), { status: 503 })),
  });
  assertEquals(incomplete, { ok: false, reason: "incomplete" });
});

Deno.test("grant cleanup fails closed when the worker cannot be reached", async () => {
  const result = await revokeUserOauthGrants({
    authorization: "Bearer user-jwt",
    cleanupUrl: "https://mcp.example/account/grants/cleanup",
    fetchImpl: () => Promise.reject(new Error("offline")),
  });
  assertEquals(result, { ok: false, reason: "unreachable" });
});
