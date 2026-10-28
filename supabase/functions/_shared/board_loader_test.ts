import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { loadBoardContent, loadBoardLines } from "./board_loader.ts";
import { classifyWebhookPayload } from "./push_helpers.ts";

function client(
  data: unknown,
  error: unknown = null,
  prefs: unknown = { max_lines: 6 },
  prefsError: unknown = null,
) {
  return {
    from(table: string) {
      const result = table === "reminders"
        ? { data, error }
        : { data: prefs, error: prefsError };
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

Deno.test("failed preferences read cannot truncate an eight-reminder board to the default", async () => {
  const rows = Array.from(
    { length: 8 },
    (_, i) => ({ text: `Reminder ${i + 1}` }),
  );
  assertEquals(
    await loadBoardLines(client(rows, null, { max_lines: 16 }), "user"),
    rows.map((row) => row.text),
  );
  await assertRejects(() =>
    loadBoardLines(client(rows, null, null, { message: "unavailable" }), "user")
  );
});

Deno.test("missing preferences row still uses the six-line default", async () => {
  const rows = Array.from(
    { length: 8 },
    (_, i) => ({ text: `Reminder ${i + 1}` }),
  );
  assertEquals(await loadBoardLines(client(rows, null, null), "user"), [
    ...rows.slice(0, 5).map((row) => row.text),
    "+3 more",
  ]);
});

const inserted = {
  id: "11111111-1111-4111-8111-111111111111",
  user_id: "22222222-2222-4222-8222-222222222222",
  text: "Historical text",
  is_done: false,
};

// Model the database filters so completed and other users' rows are excluded.
function boardClient(rows: (typeof inserted & {
  routine_id?: string;
  routine_fired_at?: string;
})[]) {
  return {
    from(table: string) {
      if (table !== "reminders") return client([]).from(table);
      let filtered = rows;
      const query = {
        select: () => query,
        eq: (key: string, value: unknown) => {
          filtered = filtered.filter((row) => Reflect.get(row, key) === value);
          return query;
        },
        order: () => query,
        then: (resolve: (value: unknown) => unknown) =>
          Promise.resolve({ data: filtered, error: null }).then(resolve),
      };
      return query;
    },
  };
}

for (
  const [scenario, rows] of [
    ["deleted", []],
    ["completed", [{ ...inserted, is_done: true }]],
    ["different owner", [{ ...inserted, user_id: "another-user" }]],
  ] as const
) {
  Deno.test(`delayed INSERT for ${scenario} reminder has no board content or alert`, async () => {
    const content = await loadBoardContent(
      boardClient([...rows]),
      inserted.user_id,
      inserted,
    );
    assertEquals(content, { lines: [], alertRecord: undefined });
  });
}

Deno.test("delayed INSERT uses edited current text for both board and alert", async () => {
  const current = { ...inserted, text: "Current text" };
  const content = await loadBoardContent(
    boardClient([current]),
    inserted.user_id,
    inserted,
  );
  assertEquals(content.lines, ["Current text"]);
  assertEquals(content.alertRecord?.text, "Current text");
});

Deno.test("a different active reminder cannot revive the deleted event's alert", async () => {
  const other = {
    ...inserted,
    id: "33333333-3333-4333-8333-333333333333",
    text: "Other",
  };
  const content = await loadBoardContent(
    boardClient([other]),
    inserted.user_id,
    inserted,
  );
  assertEquals(content, { lines: ["Other"], alertRecord: undefined });
});

for (const type of ["INSERT", "UPDATE"] as const) {
  Deno.test(`routine ${type} alerts only for the current firing`, async () => {
    const event = {
      ...inserted,
      routine_id: "33333333-3333-4333-8333-333333333333",
      routine_fired_at: "2026-10-22T08:00:00Z",
    };
    const check = classifyWebhookPayload({
      type,
      table: "reminders",
      schema: "public",
      record: event,
      old_record: { routine_fired_at: null },
    });
    assertEquals(
      check.ok && check.kind === "process" && check.sendsAlert,
      true,
    );
    const current = { ...event, routine_fired_at: "2026-10-23T08:00:00Z" };
    const stale = await loadBoardContent(
      boardClient([current]),
      inserted.user_id,
      event,
    );
    assertEquals(stale.alertRecord, undefined);
    assertEquals(stale.lines, [current.text]);
    const fresh = await loadBoardContent(
      boardClient([event]),
      inserted.user_id,
      event,
    );
    assertEquals(fresh.alertRecord, event);
  });
}

Deno.test("alert candidate does not turn a failed board read into push content", async () => {
  await assertRejects(() =>
    loadBoardContent(
      client(null, { message: "unavailable" }),
      inserted.user_id,
      inserted,
    )
  );
});
