import { decideLiveActivity, parseStartedAtMs } from "./live_activity.ts";

export type SendResult = "sent" | "retryable" | "failed" | "invalid";

export async function reconcileLiveActivity(input: {
  lines: string[];
  activityToken: string | null;
  startToken: string | null;
  retiringToken: string | null;
  startedAt: string | null;
  nowMs: number;
  quiet?: boolean;
  hasAlert: boolean;
  send: (
    event: "start" | "update" | "end",
    destination: "push-to-start" | "activity" | "retiring",
  ) => Promise<SendResult>;
  recordStart: (replacing: boolean) => Promise<void>;
  recordEnd: () => Promise<void>;
  recordAdoption: () => Promise<void>;
  clearRetiring: () => Promise<void>;
}): Promise<{ results: SendResult[]; deliveredAlert: boolean }> {
  const results: SendResult[] = [];
  const empty = input.lines.length === 0;
  const acknowledgedToken = input.activityToken !== input.retiringToken
    ? input.activityToken
    : null;
  // APNs acceptance is not delivery. A different update token acknowledges
  // the replacement; until then the old banner must remain visible.
  if (input.retiringToken) {
    if (empty || acknowledgedToken) {
      const result = await input.send("end", "retiring");
      results.push(result);
      if (result === "sent") {
        await input.clearRetiring();
      } else if (result !== "invalid") {
        // An invalid token is cleared by the transport. Other failures leave
        // it for the next pass, without losing another banner to retirement.
        return { results, deliveredAlert: false };
      }
    }
  }

  if (empty && !acknowledgedToken) {
    await input.recordEnd();
    return { results, deliveredAlert: false };
  }

  const startedAtMs = parseStartedAtMs(input.startedAt);
  const decision = decideLiveActivity({
    lines: input.lines,
    hasPushToStartToken: input.startToken !== null,
    hasActivityToken: acknowledgedToken !== null,
    startedAtMs,
    nowMs: input.nowMs,
    quiet: input.quiet,
  });

  if (decision.kind === "noop") return { results, deliveredAlert: false };
  if (decision.kind === "end") {
    const result = await input.send("end", "activity");
    results.push(result);
    if (result === "sent" || result === "invalid") await input.recordEnd();
    return { results, deliveredAlert: false };
  }
  if (decision.kind === "update") {
    const result = await input.send("update", "activity");
    results.push(result);
    if (result === "sent") {
      if (startedAtMs === null) await input.recordAdoption();
      return { results, deliveredAlert: input.hasAlert };
    }
    // Only an invalid activity token confirms that this destination is gone.
    if (result !== "invalid" || !input.startToken) {
      return { results, deliveredAlert: false };
    }
  }

  const result = await input.send("start", "push-to-start");
  results.push(result);
  if (result === "sent") {
    await input.recordStart(decision.kind === "recycle");
  }
  return { results, deliveredAlert: result === "sent" && input.hasAlert };
}
