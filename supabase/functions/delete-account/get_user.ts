import {
  createClient,
  isAuthRetryableFetchError,
} from "https://esm.sh/@supabase/supabase-js@2.112.1";

export async function getDeleteAccountUser(
  supabaseUrl: string,
  anonKey: string,
  authorization: string,
  fetchImpl: typeof fetch = fetch,
) {
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization }, fetch: fetchImpl },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error) {
    return {
      user: null,
      unavailable: isAuthRetryableFetchError(error) ||
        (error.status ?? 0) >= 500,
    };
  }
  return { user };
}
