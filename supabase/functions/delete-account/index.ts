import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleDeleteAccount } from "./handler.ts";

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

Deno.serve((request) =>
  handleDeleteAccount(request, {
    env: (name) => Deno.env.get(name),
    fetchImpl: fetch,
    nowSeconds: () => Math.floor(Date.now() / 1000),
    warn: (payload) => console.warn(JSON.stringify(payload)),
    getUser: async (authorization) => {
      const userClient = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_ANON_KEY"),
        {
          global: { headers: { Authorization: authorization } },
          auth: { persistSession: false, autoRefreshToken: false },
        },
      );
      const { data: { user }, error } = await userClient.auth.getUser();
      if (error || !user) return { user: null };
      return { user };
    },
    deleteRows: async (table, userId) => {
      const admin = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const { error } = await admin.from(table).delete().eq("user_id", userId);
      return { error };
    },
    deleteAuthUser: async (userId) => {
      const admin = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const { error } = await admin.auth.admin.deleteUser(userId);
      return { error };
    },
  }).catch((error) => {
    if (
      error instanceof Error &&
      error.message.startsWith("Missing required environment variable:")
    ) {
      console.error("Edge Function configuration error", error);
      return new Response("Server configuration error", {
        status: 500,
        headers: corsHeaders,
      });
    }
    return Promise.reject(error);
  })
);
