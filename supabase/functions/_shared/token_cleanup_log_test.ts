import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { pruneAlertToken } from "./alert_token_store.ts";
import { createDeliveryClient } from "./delivery_client.ts";
import { markActivityEnded } from "./live_activity_store.ts";

const alertToken = "a".repeat(64);
const activityToken = "b".repeat(64);
const registration = "2026-10-28T00:00:00.000Z";

for (const operation of ["alert pruning", "Live Activity end"] as const) {
  for (const failure of ["connection", "known code", "unrecognized code"]) {
    Deno.test(`${operation} logs safely on ${failure} failure`, async () => {
      let requestUrl: URL | undefined;
      const db = createDeliveryClient(
        "https://database.invalid",
        "test-key",
        (input) => {
          requestUrl = new URL(String(input));
          const diagnostic = `error sending request for url (${requestUrl})`;
          if (failure === "connection") {
            return Promise.reject(new TypeError(diagnostic));
          }
          return Promise.resolve(Response.json({
            code: failure === "known code" ? "42501" : alertToken,
            message: diagnostic,
            details: diagnostic,
            hint: diagnostic,
          }, { status: 403 }));
        },
      );
      const logged: unknown[][] = [];
      const originalError = console.error;
      let rejected = false;
      try {
        console.error = (...args: unknown[]) => logged.push(args);
        const cleanup = operation === "alert pruning"
          ? pruneAlertToken(db, {
            token: alertToken,
            user_id: "owner",
            updated_at: registration,
          }, { kind: "prune", status: 410, reason: "Unregistered" })
          : markActivityEnded(
            db,
            "owner",
            alertToken,
            activityToken,
            registration,
          );
        await cleanup.catch(() => {
          rejected = true;
        });
      } finally {
        console.error = originalError;
      }

      assertEquals(rejected, operation === "Live Activity end");
      assertEquals(
        requestUrl?.searchParams.get("token") === `eq.${alertToken}`,
        true,
      );
      if (operation === "Live Activity end") {
        assertEquals(
          requestUrl?.searchParams.get("activity_push_token") ===
            `eq.${activityToken}`,
          true,
        );
      }
      const rendered = Deno.inspect(logged);
      assertEquals({
        alertTokenLogged: rendered.includes(alertToken),
        activityTokenLogged: rendered.includes(activityToken),
      }, { alertTokenLogged: false, activityTokenLogged: false });
      assertEquals(logged, [[
        operation === "alert pruning"
          ? "Could not remove expired APNs token"
          : "Could not record Live Activity end",
        failure === "known code" ? "42501" : "unknown",
      ]]);
    });
  }
}
