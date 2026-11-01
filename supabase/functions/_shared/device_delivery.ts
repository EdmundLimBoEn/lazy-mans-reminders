import { loadBoardContent } from "./board_loader.ts";
import type { SendResult } from "./live_activity_lifecycle.ts";
import type { ReminderRecord } from "./push_helpers.ts";

export type ServiceClient = {
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type DeviceRow = {
  token: string;
  user_id: string;
  environment: string;
  updated_at: string;
  push_to_start_token: string | null;
  activity_push_token: string | null;
  activity_started_at: string | null;
  retiring_activity_push_token: string | null;
};

export const DEVICE_SELECT =
  "token, user_id, environment, updated_at, push_to_start_token, activity_push_token, activity_started_at, retiring_activity_push_token";

// The database slot lasts 120 seconds. Stop starting requests after 90 seconds,
// leaving room for the transport's 10-second timeout before another claim.
export const DELIVERY_SEND_WINDOW_MS = 90_000;

/** Every invocation uses the same database slot, including refresh and end. */
export async function deliverDevices(input: {
  supabase: ServiceClient;
  devices: DeviceRow[];
  alertCandidate?: ReminderRecord;
  deliver: (
    device: DeviceRow,
    content: Awaited<ReturnType<typeof loadBoardContent>>,
    assertCurrent: () => void,
  ) => Promise<SendResult[]>;
  now?: () => number;
}): Promise<SendResult[]> {
  const results: SendResult[] = [];
  const now = input.now ?? (() => performance.now());
  for (const observed of input.devices) {
    const args = {
      p_device_token: observed.token,
      p_user_id: observed.user_id,
      p_lease_id: crypto.randomUUID(),
    };
    const deadline = now() + DELIVERY_SEND_WINDOW_MS;
    const assertCurrent = () => {
      if (now() >= deadline) throw new Error("Device delivery slot expired");
    };
    let claimed = false;
    try {
      const { data, error } = await input.supabase.rpc(
        "claim_device_delivery",
        args,
      );
      if (error) throw new Error("Could not claim device delivery");
      if (data !== true) {
        results.push("retryable");
        continue;
      }
      claimed = true;
      assertCurrent();
      // Registration and content may have changed while other devices sent.
      const { data: device, error: deviceError } = await input.supabase
        .from("device_tokens").select(DEVICE_SELECT)
        .eq("token", observed.token).eq("user_id", observed.user_id)
        .maybeSingle();
      if (deviceError) throw new Error("Could not reload device registration");
      if (!device) continue;
      const content = await loadBoardContent(
        input.supabase,
        observed.user_id,
        input.alertCandidate,
      );
      assertCurrent();
      results.push(...await input.deliver(device, content, assertCurrent));
    } catch {
      results.push("retryable");
    } finally {
      if (claimed) {
        try {
          const { error } = await input.supabase.rpc(
            "release_device_delivery",
            args,
          );
          if (error) results.push("retryable");
        } catch {
          results.push("retryable");
        }
      }
    }
  }
  return results;
}
