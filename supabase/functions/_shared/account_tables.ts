/** Tables owned by an auth user. Deleted before `auth.admin.deleteUser`. */
export const USER_DATA_TABLES = [
  "agent_tokens",
  "reminders",
  "device_tokens",
  "lock_screen_prefs",
] as const;
