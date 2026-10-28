import { defineConfig } from 'vitest/config'

export default defineConfig({
  resolve: {
    alias: { 'cloudflare:workers': new URL('./test/cloudflareWorkers.ts', import.meta.url).pathname },
  },
  test: {
    server: { deps: { inline: ['@cloudflare/workers-oauth-provider'] } },
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
})
