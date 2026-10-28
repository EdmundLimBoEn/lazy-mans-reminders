import type { ServiceClient } from "./device_delivery.ts";
import type { SendResult } from "./live_activity_lifecycle.ts";

export type PushJob = {
  id: string;
  user_id: string;
  device_token: string;
  payload: unknown;
  status: string;
  outcomes: Record<string, SendResult>;
  alert_sent: boolean;
};

/** Used only while holding the device delivery slot. Persist before the next send. */
export function pushReplay(
  supabase: ServiceClient,
  job: PushJob,
  assertCurrent: () => void,
) {
  async function save(patch: Partial<PushJob>) {
    assertCurrent();
    const { data, error } = await supabase.from("reminder_push_jobs")
      .update(patch).eq("id", job.id).eq("status", "pending")
      .select("id").maybeSingle();
    if (error || !data) {
      throw new Error("Could not save push delivery progress");
    }
    Object.assign(job, patch);
  }
  return {
    get alertSent() {
      return job.alert_sent;
    },
    async send(
      key: string,
      carriesAlert: boolean,
      send: () => Promise<SendResult>,
    ) {
      const previous = job.outcomes[key];
      if (previous && previous !== "retryable") return previous;
      assertCurrent();
      const result = await send();
      await save({
        outcomes: { ...job.outcomes, [key]: result },
        alert_sent: job.alert_sent || (carriesAlert && result === "sent"),
      });
      return result;
    },
    async finish(results: SendResult[]) {
      if (!results.includes("retryable")) await save({ status: "complete" });
    },
  };
}
export type PushReplay = ReturnType<typeof pushReplay>;
