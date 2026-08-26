import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { USER_DATA_TABLES } from "./account_tables.ts";

Deno.test("account deletion covers every user-owned table", () => {
  assertEquals([...USER_DATA_TABLES].sort(), [
    "agent_tokens",
    "device_tokens",
    "lock_screen_prefs",
    "reminders",
  ]);
});
