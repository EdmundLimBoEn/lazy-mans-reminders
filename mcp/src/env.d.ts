/// <reference types="@cloudflare/workers-types" />

interface Env {
  SUPABASE_URL: string
  SUPABASE_SERVICE_ROLE_KEY: string
  SUPABASE_ANON_KEY: string
  WEB_ORIGINS: string
  OAUTH_KV: KVNamespace
}
