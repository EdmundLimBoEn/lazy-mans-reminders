/** Live Activity board lines, lifecycle decision, and APNs payloads. */

export const LIVE_ACTIVITY_ATTRIBUTES_TYPE = "ReminderAttributes";
export const LIVE_ACTIVITY_FALLBACK_MAX_LINES = 6;
/** Recycle before Apple's 8h active cap so the banner does not vanish with reminders still on the board. */
export const LIVE_ACTIVITY_RECYCLE_AFTER_MS = 7 * 60 * 60 * 1000;
/** Skip a second start while the phone may still be uploading the per-activity update token. */
export const LIVE_ACTIVITY_START_GRACE_MS = 2 * 60 * 1000;
export const LIVE_ACTIVITY_STALE_AFTER_SECONDS = 8 * 60 * 60;
export const LIVE_ACTIVITY_TOKEN_PATTERN = /^[0-9a-f]{64,512}$/i;

export type LiveActivityDecision =
  | { kind: "noop" }
  | { kind: "start" }
  | { kind: "update" }
  | { kind: "end" }
  | { kind: "recycle" };

export function parseLiveActivityToken(
  value: string | null | undefined,
): string | null {
  if (typeof value !== "string") return null;
  return LIVE_ACTIVITY_TOKEN_PATTERN.test(value) ? value : null;
}

export function parseStartedAtMs(
  value: string | null | undefined,
): number | null {
  if (typeof value !== "string" || value.length === 0) return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

export function boardLines(texts: string[], limit: number): string[] {
  const cap = Math.max(1, limit);
  const flattened = texts.flatMap((text) =>
    text.split("\n").map((line) => line.trim()).filter((line) => line.length > 0)
  );
  if (flattened.length === 0) return [];
  if (flattened.length <= cap) return flattened;
  const visible = flattened.slice(0, Math.max(cap - 1, 0));
  const overflow = flattened.length - visible.length;
  return [...visible, `+${overflow} more`];
}

export function decideLiveActivity(input: {
  lines: string[];
  hasPushToStartToken: boolean;
  hasActivityToken: boolean;
  startedAtMs: number | null;
  nowMs: number;
}): LiveActivityDecision {
  if (input.lines.length === 0) {
    return input.hasActivityToken ? { kind: "end" } : { kind: "noop" };
  }

  const ageMs = input.startedAtMs == null
    ? null
    : input.nowMs - input.startedAtMs;

  if (
    input.hasActivityToken &&
    ageMs != null &&
    ageMs >= LIVE_ACTIVITY_RECYCLE_AFTER_MS
  ) {
    return input.hasPushToStartToken ? { kind: "recycle" } : { kind: "update" };
  }

  if (input.hasActivityToken) return { kind: "update" };

  if (
    input.hasPushToStartToken &&
    ageMs != null &&
    ageMs >= 0 &&
    ageMs < LIVE_ACTIVITY_START_GRACE_MS
  ) {
    return { kind: "noop" };
  }

  if (input.hasPushToStartToken) return { kind: "start" };
  return { kind: "noop" };
}

export function liveActivityTopic(bundleId: string): string {
  return `${bundleId}.push-type.liveactivity`;
}

export function buildLiveActivityHeaders(input: {
  jwt: string;
  bundleId: string;
}): Record<string, string> {
  return {
    authorization: `bearer ${input.jwt}`,
    "content-type": "application/json",
    "apns-topic": liveActivityTopic(input.bundleId),
    "apns-push-type": "liveactivity",
    "apns-priority": "10",
  };
}

export function liveActivityStaleDateUnix(nowUnix: number): number {
  return nowUnix + LIVE_ACTIVITY_STALE_AFTER_SECONDS;
}

export function buildLiveActivityPayload(input: {
  event: "start" | "update" | "end";
  lines: string[];
  timestamp: number;
  alertBody?: string;
  staleDate: number;
  dismissalDate?: number;
}): string {
  const aps: Record<string, unknown> = {
    timestamp: input.timestamp,
    event: input.event,
    "content-state": { lines: input.lines },
    "stale-date": input.staleDate,
    "relevance-score": 100,
  };

  if (input.event === "start") {
    aps["attributes-type"] = LIVE_ACTIVITY_ATTRIBUTES_TYPE;
    aps.attributes = {};
    aps.alert = {
      body: input.alertBody ?? input.lines[0] ?? "Reminders",
    };
  } else if (input.alertBody) {
    aps.alert = { body: input.alertBody };
  }

  if (input.event === "end") {
    aps["dismissal-date"] = input.dismissalDate ?? 1;
  }

  return JSON.stringify({ aps });
}
