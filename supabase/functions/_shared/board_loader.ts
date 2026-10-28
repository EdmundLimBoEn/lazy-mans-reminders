import type { ReminderRecord } from "./push_helpers.ts";
import {
  boardLines,
  LIVE_ACTIVITY_FALLBACK_MAX_LINES,
} from "./live_activity.ts";

type BoardClient = {
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
};

export async function loadBoardLines(
  supabase: BoardClient,
  userId: string,
): Promise<string[]> {
  return (await loadBoardContent(supabase, userId)).lines;
}

/** Build push content solely from the current active board, never webhook text. */
export async function loadBoardContent(
  supabase: BoardClient,
  userId: string,
  alertCandidate?: ReminderRecord,
): Promise<{ lines: string[]; alertRecord?: ReminderRecord }> {
  const [{ data: reminders, error }, { data: prefs, error: prefsError }] =
    await Promise.all([
      supabase.from("reminders").select(
        "id, user_id, text, routine_id, routine_fired_at",
      ).eq("user_id", userId)
        .eq("is_done", false).order("sort_order", { ascending: true })
        .order("created_at", { ascending: true }),
      supabase.from("lock_screen_prefs").select("max_lines")
        .eq("user_id", userId).maybeSingle(),
    ]);
  // A failed read is not an empty board: ending banners here loses valid reminders.
  if (error || !Array.isArray(reminders)) {
    throw new Error("Could not load reminder board");
  }
  // Only a missing preference row may use defaults; failed reads must preserve
  // existing activity content through the caller's retryable delivery path.
  if (prefsError) {
    throw new Error("Could not load lock-screen preferences");
  }
  const texts = reminders.map((row: { text: string }) => row.text);
  const current = alertCandidate &&
    reminders.find((row: ReminderRecord) =>
      row.id === alertCandidate.id && row.user_id === userId
    );
  // A delayed routine event must not alert for a newer firing of the same row.
  const alertRecord = current &&
      (current.routine_id ?? null) === (alertCandidate?.routine_id ?? null) &&
      (current.routine_fired_at ?? null) ===
        (alertCandidate?.routine_fired_at ?? null)
    ? current
    : undefined;
  return {
    alertRecord,
    lines: boardLines(
      texts,
      typeof prefs?.max_lines === "number"
        ? prefs.max_lines
        : LIVE_ACTIVITY_FALLBACK_MAX_LINES,
    ),
  };
}
