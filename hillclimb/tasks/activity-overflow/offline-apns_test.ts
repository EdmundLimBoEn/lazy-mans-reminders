import { boardContent, buildLiveActivityPayload } from "../../../supabase/functions/_shared/live_activity.ts";
import { loadBoardContent } from "../../../supabase/functions/_shared/board_loader.ts";
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
}
Deno.test("ten multiline originals retain five hidden lines in legacy-compatible APNs", () => {
  const content = boardContent([Array.from({length: 10}, (_, i) => `Line ${i + 1}`).join("\n")], 6);
  equal(content, {lines: ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5", "+5 more"], hiddenLineCount: 5});
  const payload = buildLiveActivityPayload({...content, event: "update", timestamp: 1, staleDate: 2});
  equal(JSON.parse(payload).aps["content-state"], content);
});
Deno.test("payload cap counts metadata, Unicode and huge alerts for every event", () => {
  for (const text of ["漢", "😀", "é", '\"\\']) {
    for (const event of ["start", "update", "end"] as const) {
      const content = boardContent([Array(10).fill(text.repeat(6000)).join("\n")], 6);
      const payload = buildLiveActivityPayload({...content, event, timestamp: 1, staleDate: 2, alertBody: text.repeat(6000)});
      if (new TextEncoder().encode(payload).length > 4096) throw new Error("Payload exceeds APNs limit");
      const state = JSON.parse(payload).aps["content-state"];
      equal(state.lines.length - 1 + state.hiddenLineCount, 10);
      equal(state.lines.at(-1), `+${state.hiddenLineCount} more`);
      if (state.lines.some((line: string) => !line.length)) throw new Error("Empty original");
    }
  }
});
Deno.test("literal summary and empty lines remain text, legacy input stays additive-free", () => {
  equal(boardContent(["+5 more\nSecond"], 6), {lines: ["+5 more", "Second"], hiddenLineCount: 0});
  equal(boardContent([" \n\n "], 6), {lines: [], hiddenLineCount: 0});
  equal(JSON.parse(buildLiveActivityPayload({lines: ["+5 more"], event: "update", timestamp: 1, staleDate: 2})).aps["content-state"], {lines: ["+5 more"]});
});
Deno.test("mock board loader carries metadata with no service calls", async () => {
  const q = {select: () => q, eq: () => q, order: () => q,
    then: (resolve: (value: unknown) => unknown) => Promise.resolve({data: [{text: Array(10).fill("Line").join("\n")}], error: null}).then(resolve)};
  const content = await loadBoardContent({from: (table: string) => table === "reminders" ? q : {select: () => ({eq: () => ({maybeSingle: () => Promise.resolve({data: {max_lines: 6}, error: null})})})}}, "offline");
  equal(content.hiddenLineCount, 5);
  equal(content.lines.at(-1), "+5 more");
});
