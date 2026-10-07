import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadBoardLines } from "./board_loader.ts";

function client(data: unknown, error: unknown = null) {
  return {
    from(table: string) {
      const result = table === "reminders"
        ? { data, error }
        : { data: { max_lines: 6 }, error: null };
      const query = {
        select: () => query,
        eq: () => query,
        order: () => query,
        maybeSingle: () => Promise.resolve(result),
        then: (resolve: (value: typeof result) => unknown) =>
          Promise.resolve(result).then(resolve),
      };
      return query;
    },
  };
}

Deno.test("database outage never becomes an empty board that ends live activities", async () => {
  await assertRejects(() =>
    loadBoardLines(client(null, { message: "unavailable" }), "user")
  );
});
Deno.test("missing query data stays retryable even without an error object", async () => {
  await assertRejects(() => loadBoardLines(client(null), "user"));
});
Deno.test("confirmed empty board can end the activity", async () => {
  assertEquals(await loadBoardLines(client([]), "user"), []);
});
Deno.test("nonempty board keeps its content", async () => {
  assertEquals(await loadBoardLines(client([{ text: "Buy milk" }]), "user"), [
    "Buy milk",
  ]);
});
