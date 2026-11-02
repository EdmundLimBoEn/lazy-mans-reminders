import type { ServiceClient } from "./device_delivery.ts";
import type { SendResult } from "./live_activity_lifecycle.ts";

export type StartTransition = {
  previousToken: string | null;
  startedAt: string;
  replacing: boolean;
};

export type PushJob = {
  id: string;
  user_id: string;
  device_token: string;
  payload: unknown;
  status: string;
  outcomes: Record<
    string,
    SendResult | { result: "sent"; start: StartTransition }
  >;
  alert_sent: boolean;
};

/** Used only while holding the device delivery slot. Persist before the next send. */
export function pushReplay(
  supabase: ServiceClient,
  job: PushJob,
  assertCurrent: () => void,
) {
  let alertSent = job.alert_sent;
  let acceptedStart: StartTransition | undefined;
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
      return alertSent;
    },
    get acceptedStart() {
      return acceptedStart;
    },
    async send(
      key: string,
      carriesAlert: boolean,
      send: () => Promise<SendResult>,
      destinationToken?: string | null,
      start?: StartTransition,
    ) {
      if (destinationToken !== undefined) {
        // Do not reuse legacy, unscoped outcomes or put raw APNs tokens in keys.
        const digest = await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(JSON.stringify(destinationToken)),
        );
        const identity = Array.from(
          new Uint8Array(digest),
          (byte) => byte.toString(16).padStart(2, "0"),
        ).join("");
        key = `${key}:${identity}`;
      }
      const previous = job.outcomes[key];
      if (previous && previous !== "retryable") {
        if (start) {
          acceptedStart = typeof previous === "object"
            ? previous.start
            : undefined;
        }
        return typeof previous === "object" ? previous.result : previous;
      }
      assertCurrent();
      const result = await send();
      // Acceptance must suppress fallback even if saving progress fails.
      alertSent ||= carriesAlert && result === "sent";
      if (start && result === "sent") acceptedStart = start;
      await save({
        outcomes: {
          ...job.outcomes,
          [key]: start && result === "sent" ? { result, start } : result,
        },
        alert_sent: alertSent,
      });
      return result;
    },
    async finish(results: SendResult[]) {
      if (!results.includes("retryable")) await save({ status: "complete" });
    },
  };
}
export type PushReplay = ReturnType<typeof pushReplay>;
