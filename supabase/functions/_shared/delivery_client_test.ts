import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createDeliveryClient } from "./delivery_client.ts";
import { deliverDevices, type DeviceRow } from "./device_delivery.ts";

for (
  const stage of [
    "claim_device_delivery",
    "device_tokens",
    "reminders",
    "lock_screen_prefs",
    "complete_live_activity_start",
    "release_device_delivery",
  ]
) {
  for (const stalledBody of [false, true]) {
    Deno.test(`${stage}: stalled ${stalledBody ? "body" : "request"} aborts and later devices advance`, async () => {
      const devices: DeviceRow[] = ["a", "b"].map((token) => ({
        token,
        user_id: "owner",
        environment: "production",
        updated_at: new Date(0).toISOString(),
        push_to_start_token: null,
        activity_push_token: null,
        activity_started_at: null,
        retiring_activity_push_token: null,
      }));
      let current = "";
      let stalledSignal: AbortSignal | undefined;
      const released: string[] = [];
      const sent: string[] = [];
      const client = createDeliveryClient(
        "https://database.invalid",
        "test-key",
        (input, init) => {
          const path = new URL(String(input)).pathname.split("/").at(-1)!;
          if (path === "claim_device_delivery") {
            current = JSON.parse(String(init?.body)).p_device_token;
          }
          if (path === "release_device_delivery") {
            assertEquals(init?.signal?.aborted, false);
            released.push(current);
          }
          if (current === "a" && path === stage) {
            stalledSignal = init?.signal ?? undefined;
            if (stalledBody) {
              return Promise.resolve(
                new Response(
                  new ReadableStream({
                    start(controller) {
                      stalledSignal?.addEventListener(
                        "abort",
                        () => controller.error(stalledSignal!.reason),
                        {
                          once: true,
                        },
                      );
                    },
                  }),
                ),
              );
            }
            return new Promise((_resolve, reject) => {
              stalledSignal?.addEventListener(
                "abort",
                () => reject(stalledSignal!.reason),
                { once: true },
              );
            });
          }
          const data = path === "device_tokens"
            ? devices.find((d) => d.token === current)
            : path === "reminders"
            ? [{ id: "reminder", user_id: "owner", text: "Current" }]
            : path === "lock_screen_prefs"
            ? { max_lines: 6 }
            : true;
          return Promise.resolve(Response.json(data));
        },
        10,
      );
      let watchdog: ReturnType<typeof setTimeout> | undefined;
      try {
        const results = await Promise.race([
          deliverDevices({
            supabase: client,
            devices,
            deliver: async (device) => {
              const { error } = await client.rpc(
                "complete_live_activity_start",
                {},
              );
              if (error) throw new Error("Bookkeeping failed");
              sent.push(device.token);
              return ["sent"];
            },
          }),
          new Promise<never>((_resolve, reject) => {
            watchdog = setTimeout(
              () => reject(new Error("Delivery remained blocked")),
              1000,
            );
          }),
        ]);
        assertEquals(stalledSignal?.aborted, true);
        assertEquals(sent.includes("b"), true);
        assertEquals(
          released,
          stage === "claim_device_delivery" ? ["b"] : ["a", "b"],
        );
        if (stage !== "lock_screen_prefs") {
          assertEquals(results.includes("retryable"), true);
        }
        if (!["lock_screen_prefs", "release_device_delivery"].includes(stage)) {
          assertEquals(sent, ["b"]);
        }
      } finally {
        clearTimeout(watchdog);
      }
    });
  }
}

Deno.test("delivery client preserves caller cancellation", async () => {
  const controller = new AbortController();
  const client = createDeliveryClient(
    "https://database.invalid",
    "test-key",
    (_input, init) => {
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener(
          "abort",
          () => reject(init.signal!.reason),
          { once: true },
        );
        controller.abort();
      });
    },
  );
  await assertRejects(() =>
    client.from("reminders").select().abortSignal(controller.signal)
      .throwOnError().then()
  );
});
