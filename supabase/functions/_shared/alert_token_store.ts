import type { DeviceRow, ServiceClient } from "./device_delivery.ts";
import { postgrestErrorCodeForLog } from "./postgrest_error_log.ts";
import type { ApnsOutcome, PruneResult } from "./push_helpers.ts";

export async function pruneAlertToken(
  supabase: Pick<ServiceClient, "from">,
  device: Pick<DeviceRow, "token" | "user_id" | "updated_at">,
  outcome: Extract<ApnsOutcome, { kind: "prune" }>,
): Promise<PruneResult> {
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
  const { data, error } = await query.select("token").maybeSingle();
  if (error) {
    console.error(
      "Could not remove expired APNs token",
      postgrestErrorCodeForLog(error.code),
    );
    throw new Error("Could not remove expired APNs token");
  }
  if (data !== null) return "pruned";

  // Replay reloads the registration before attempting another send.
  const { data: refreshed, error: refreshError } = await supabase
    .from("device_tokens").select("token")
    .eq("token", device.token)
    .eq("user_id", device.user_id)
    .gt("updated_at", device.updated_at)
    .maybeSingle();
  if (refreshError) throw new Error("Could not reload device registration");
  return refreshed ? "retryable" : "invalid";
}
