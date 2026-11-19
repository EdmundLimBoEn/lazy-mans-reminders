import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anonKey) {
  throw new Error('Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY')
}

// Keep the SDK's default key so existing browser sessions are preserved.
export const authStorageKey = `sb-${new URL(url).hostname.split('.')[0]}-auth-token`

export const supabase = createClient(url, anonKey, {
  global: { headers: { 'x-notepad-client': 'web' } },
  auth: {
    storageKey: authStorageKey,
    flowType: 'pkce',
    detectSessionInUrl: false,
    persistSession: true,
    autoRefreshToken: true,
    experimental: {
      appendPkceFlowIdToRedirects: true,
    },
  },
})
