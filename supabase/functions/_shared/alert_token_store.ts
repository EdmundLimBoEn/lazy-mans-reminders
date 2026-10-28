import type { DeviceRow, ServiceClient } from "./device_delivery.ts";
import type { ApnsOutcome } from "./push_helpers.ts";

export async function pruneAlertToken(
  supabase: Pick<ServiceClient, "from">,
  device: Pick<DeviceRow, "token" | "user_id" | "updated_at">,
  outcome: Extract<ApnsOutcome, { kind: "prune" }>,
): Promise<void> {
  // Match the exact revision read before sending, including sub-millisecond
  // precision. A registration refreshed during the request must survive.
  let query = supabase.from("device_tokens").delete()
    .eq("token", device.token)
    .eq("user_id", device.user_id)
    .eq("updated_at", device.updated_at);
  if (outcome.invalidatedAtMs !== undefined) {
    // Let Postgres compare timestamps without rounding the registration time.
    query = query.lte(
      "updated_at",
      new Date(outcome.invalidatedAtMs).toISOString(),
    );
  }
  const { error } = await query;
  if (error) console.error("Could not remove expired APNs token", error);
}
