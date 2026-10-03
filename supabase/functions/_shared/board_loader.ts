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
  insertedText?: string,
): Promise<string[]> {
  const [{ data: reminders, error }, { data: prefs }] = await Promise.all([
    supabase.from("reminders").select("text").eq("user_id", userId)
      .eq("is_done", false).order("sort_order", { ascending: true })
      .order("created_at", { ascending: true }),
    supabase.from("lock_screen_prefs").select("max_lines")
      .eq("user_id", userId).maybeSingle(),
  ]);
  // A failed read is not an empty board: ending banners here loses valid reminders.
  if (error || !Array.isArray(reminders)) {
    throw new Error("Could not load reminder board");
  }
  const texts = reminders.map((row: { text: string }) => row.text);
  if (insertedText && !texts.includes(insertedText)) texts.push(insertedText);
  return boardLines(
    texts,
    typeof prefs?.max_lines === "number"
      ? prefs.max_lines
      : LIVE_ACTIVITY_FALLBACK_MAX_LINES,
  );
}
