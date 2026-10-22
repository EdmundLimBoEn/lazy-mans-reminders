type ActivityClient = {
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
};

export async function markActivityEnded(
  supabase: ActivityClient,
  userId: string,
  alertToken: string,
  expectedToken: string | null,
  expectedStartedAt: string | null,
): Promise<void> {
  let query = supabase
    .from("device_tokens")
    .update({
      activity_push_token: null,
      activity_started_at: null,
    })
    .eq("token", alertToken)
    .eq("user_id", userId);
  // APNs may finish after a replacement is registered. Clear only the
  // activity we observed, including a start still awaiting its token.
  query = expectedToken === null
    ? query.is("activity_push_token", null)
    : query.eq("activity_push_token", expectedToken);
  query = expectedStartedAt === null
    ? query.is("activity_started_at", null)
    : query.eq("activity_started_at", expectedStartedAt);
  const { error } = await query;
  if (error) {
    console.error("Could not record Live Activity end", error);
  }
}
