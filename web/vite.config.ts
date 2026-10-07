/// <reference types="vitest/config" />
import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: [
      { find: '@', replacement: fileURLToPath(new URL('./src', import.meta.url)) },
      // Radix Dialog's scroll lock (react-remove-scroll) injects a <style> tag, which
      // CSP style-src 'self' blocks. This drop-in uses a constructable stylesheet instead.
      { find: /^react-style-singleton$/, replacement: fileURLToPath(new URL('./src/lib/cspStyleSingleton.ts', import.meta.url)) },
    ],
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
})
