/** Live Activity board lines, lifecycle decision, and APNs payloads. */

export const LIVE_ACTIVITY_ATTRIBUTES_TYPE = "ReminderAttributes";
export const LIVE_ACTIVITY_FALLBACK_MAX_LINES = 6;
/** Recycle before Apple's 8h active cap so the banner does not vanish with reminders still on the board. */
export const LIVE_ACTIVITY_RECYCLE_AFTER_MS = 7 * 60 * 60 * 1000;
/** Skip a second start while the phone may still be uploading the per-activity update token. */
export const LIVE_ACTIVITY_START_GRACE_MS = 2 * 60 * 1000;
export const LIVE_ACTIVITY_STALE_AFTER_SECONDS = 8 * 60 * 60;
export const LIVE_ACTIVITY_TOKEN_PATTERN = /^[0-9a-f]{64,512}$/i;
export const APNS_PAYLOAD_BYTE_LIMIT = 4096;
const OVERFLOW_MARK = "…";
const utf8 = new TextEncoder();

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
    text.split("\n").map((line) => line.trim()).filter((line) =>
      line.length > 0
    )
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
  quiet?: boolean;
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

  // Probe existing activities even on a quiet board; an expired token must
  // be discovered before the seven-hour renewal window.
  if (input.hasActivityToken) return { kind: "update" };

  if (input.quiet) {
    if (
      input.hasPushToStartToken &&
      ageMs != null &&
      ageMs >= 0 &&
      ageMs < LIVE_ACTIVITY_RECYCLE_AFTER_MS
    ) {
      return { kind: "noop" };
    }
  }

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
  event?: "start" | "update" | "end";
  quiet?: boolean;
}): Record<string, string> {
  return {
    authorization: `bearer ${input.jwt}`,
    "content-type": "application/json",
    "apns-topic": liveActivityTopic(input.bundleId),
    "apns-push-type": "liveactivity",
    "apns-priority": input.quiet && input.event === "update" ? "5" : "10",
  };
}

export function liveActivityStaleDateUnix(nowUnix: number): number {
  return nowUnix + LIVE_ACTIVITY_STALE_AFTER_SECONDS;
}

type LiveActivityPayloadInput = {
  event: "start" | "update" | "end";
  lines: string[];
  timestamp: number;
  alertBody?: string;
  staleDate: number;
  dismissalDate?: number;
};

function assembleLiveActivityPayload(input: LiveActivityPayloadInput): string {
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
    aps["input-push-token"] = 1;
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

export function buildLiveActivityPayload(
  input: LiveActivityPayloadInput,
): string {
  if (
    payloadBytes(assembleLiveActivityPayload(input)) <= APNS_PAYLOAD_BYTE_LIMIT
  ) {
    return assembleLiveActivityPayload(input);
  }

  const lines = input.lines.slice();
  for (
    let index = lines.length - 1;
    index >= 0 &&
    payloadBytes(assembleLiveActivityPayload({ ...input, lines })) >
      APNS_PAYLOAD_BYTE_LIMIT;
    index--
  ) {
    const next = lines.slice();
    next[index] = longestFittingText(lines[index], (candidate) => {
      next[index] = candidate;
      return assembleLiveActivityPayload({ ...input, lines: next });
    });
    lines[index] = next[index];
  }

  let alertBody = input.alertBody;
  if (
    alertBody != null &&
    payloadBytes(assembleLiveActivityPayload({ ...input, lines, alertBody })) >
      APNS_PAYLOAD_BYTE_LIMIT
  ) {
    alertBody = longestFittingText(
      alertBody,
      (candidate) =>
        assembleLiveActivityPayload({ ...input, lines, alertBody: candidate }),
    );
  }

  const fitted = lines.filter((line) => line.length > 0);
  const withMark = fitted.some((line) => line.includes(OVERFLOW_MARK))
    ? fitted
    : [...fitted, OVERFLOW_MARK];
  const payload = assembleLiveActivityPayload({
    ...input,
    lines: payloadBytes(
        assembleLiveActivityPayload({ ...input, lines: withMark, alertBody }),
      ) <= APNS_PAYLOAD_BYTE_LIMIT
      ? withMark
      : fitted,
    alertBody,
  });
  if (payloadBytes(payload) <= APNS_PAYLOAD_BYTE_LIMIT) return payload;
  return assembleLiveActivityPayload({
    ...input,
    lines: [],
    alertBody: input.event === "start" ? OVERFLOW_MARK : undefined,
  });
}

function payloadBytes(payload: string): number {
  return utf8.encode(payload).length;
}

function codePoints(value: string): string[] {
  return Array.from(value);
}

/** Longest prefix of `text` whose rendered payload fits, with an ellipsis when cut. */
function longestFittingText(
  text: string,
  render: (candidate: string) => string,
): string {
  if (payloadBytes(render(text)) <= APNS_PAYLOAD_BYTE_LIMIT) return text;
  const points = codePoints(text);
  let low = 0;
  let high = points.length;
  let best = "";
  while (low <= high) {
    const mid = (low + high) >> 1;
    const candidate = mid >= points.length
      ? text
      : `${points.slice(0, mid).join("")}${OVERFLOW_MARK}`;
    if (payloadBytes(render(candidate)) <= APNS_PAYLOAD_BYTE_LIMIT) {
      best = candidate;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  if (best.length > 0) return best;
  if (payloadBytes(render(OVERFLOW_MARK)) <= APNS_PAYLOAD_BYTE_LIMIT) {
    return OVERFLOW_MARK;
  }
  return "";
}
