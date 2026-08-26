import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { USER_DATA_TABLES } from "../_shared/account_tables.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { ...corsHeaders, allow: "POST" },
    });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  let supabaseUrl: string;
  let anonKey: string;
  let serviceRoleKey: string;
  try {
    supabaseUrl = requiredEnv("SUPABASE_URL");
    anonKey = requiredEnv("SUPABASE_ANON_KEY");
    serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  } catch (error) {
    console.error("Edge Function configuration error", error);
    return new Response("Server configuration error", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  for (const table of USER_DATA_TABLES) {
    const { error: tableError } = await admin
      .from(table)
      .delete()
      .eq("user_id", user.id);
    if (tableError) {
      console.error(`Could not delete ${table}`, tableError);
      return new Response("Could not delete account data", {
        status: 500,
        headers: corsHeaders,
      });
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("Could not delete auth user", deleteError);
    return new Response("Could not delete account", {
      status: 500,
      headers: corsHeaders,
    });
  }

  return Response.json({ ok: true }, { headers: corsHeaders });
});
