import { spawn } from 'node:child_process'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(fileURLToPath(import.meta.url))
const webRoot = join(root, '..')
const distDir = join(webRoot, 'dist')
const outDir = process.env.THEME_SCREENSHOT_DIR || '/opt/cursor/artifacts/theme-screenshots'
const port = Number(process.env.THEME_SCREENSHOT_PORT || 4173)
const origin = `http://127.0.0.1:${port}`

const viewports = [
  { name: 'desktop', width: 1280, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
]

function boardFixture(variant) {
  const empty = variant === 'empty'
  const dialog = variant === 'dialog'
  const reminders = empty
    ? `<div class="empty"><h2>Nothing to remember.</h2><p>That's either excellent or suspicious.</p></div>`
    : `<ul class="reminder-list" aria-label="Reminders">
        <li>
          <button class="check-button" type="button" aria-label="Complete">○</button>
          <span class="reminder-text">Book dentist</span>
          <div class="actions"><button type="button">Edit</button></div>
        </li>
        <li class="done">
          <button class="check-button" type="button" aria-label="Mark active">✓</button>
          <span class="reminder-text">Send the invoice</span>
          <div class="actions"><button type="button">Edit</button></div>
        </li>
      </ul>`
  const banner = empty
    ? ''
    : `<div class="error-banner" role="alert"><span>Could not save that reminder.</span><button type="button" aria-label="Dismiss">×</button></div>`
  const modal = dialog
    ? `<div class="delete-dialog-backdrop">
        <div class="delete-dialog" role="alertdialog" aria-modal="true">
          <h2>Delete your account?</h2>
          <p>This permanently removes your reminders, device registrations, lock-screen prefs, agent access, and sign-in. This cannot be undone.</p>
          <div class="delete-dialog-actions">
            <button class="danger" type="button">Delete forever</button>
            <button class="text-button" type="button">Cancel</button>
          </div>
        </div>
      </div>`
    : ''
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#f5f1e8" />
    <script src="/theme-init.js"></script>
    CSS_LINK
  </head>
  <body>
    <main class="board-shell">
      <header>
        <div>
          <p class="eyebrow">Lazy Man's Reminders</p>
          <h1>Your board</h1>
        </div>
        <div class="account">
          <div class="theme-toggle" role="group" aria-label="Theme">
            <button type="button">System</button>
            <button type="button" aria-pressed="true">Light</button>
            <button type="button">Dark</button>
          </div>
          <div class="account-meta">
            <span>you@example.com</span>
            <button class="text-button" type="button">Download my data</button>
            <button class="text-button danger-text" type="button">Delete account</button>
          </div>
        </div>
      </header>
      <section class="board">
        <form class="add-form">
          <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6z"/></svg>
          <input value="" placeholder="What shouldn't you forget?" aria-label="New reminder" />
          <button class="primary" type="submit">Add</button>
        </form>
        <div class="board-meta"><span>1/6 things on your mind</span><span>Capacity set by your iPhone Lock Screen</span></div>
        <p class="board-hint">Hint: This board is more like a post-it note. Combine reminders into one line, or find other ways to keep it short.</p>
        ${banner}
        ${reminders}
      </section>
      <section class="agent-access">
        <h2>Agent access</h2>
        <div class="connected-agents">
          <h3>Connected agents</h3>
          <p class="connected-empty">No connected agents.</p>
        </div>
      </section>
      ${modal}
    </main>
  </body>
</html>`
}

async function loadPuppeteer() {
  const specifier = process.env.PUPPETEER_CORE || 'puppeteer-core'
  try {
    const mod = await import(specifier)
    return mod.default ?? mod
  } catch {
    const require = createRequire(import.meta.url)
    return require(specifier)
  }
}

async function waitForServer() {
  const deadline = Date.now() + 20000
  while (Date.now() < deadline) {
    try {
      const response = await fetch(origin)
      if (response.ok) return
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 150))
    }
  }
  throw new Error(`Preview server did not start at ${origin}`)
}

function startPreview() {
  const child = spawn(
    process.execPath,
    [join(webRoot, 'node_modules/vite/bin/vite.js'), 'preview', '--host', '127.0.0.1', '--port', String(port), '--strictPort'],
    { cwd: webRoot, stdio: 'inherit' },
  )
  return child
}

const indexHtml = await readFile(join(distDir, 'index.html'), 'utf8')
const cssMatch = indexHtml.match(/href="(\/assets\/[^"]+\.css)"/)
if (!cssMatch) throw new Error('Built CSS not found in dist/index.html')
const cssLink = `<link rel="stylesheet" href="${cssMatch[1]}" />`

await mkdir(outDir, { recursive: true })
for (const [name, variant] of [['board', 'items'], ['board-empty', 'empty'], ['board-dialog', 'dialog']]) {
  await writeFile(join(distDir, `${name}.html`), boardFixture(variant).replace('CSS_LINK', cssLink))
}

const preview = startPreview()
process.on('exit', () => preview.kill('SIGTERM'))
await waitForServer()

const puppeteer = await loadPuppeteer()
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
  headless: 'new',
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--hide-scrollbars', '--font-render-hinting=none'],
})

const appPages = [
  { screen: 'signin', path: '/' },
  { screen: 'privacy', path: '/privacy' },
  { screen: 'connect', path: '/connect' },
  { screen: 'notfound', path: '/not-a-page' },
]
const fixturePages = [
  { screen: 'board', path: '/board.html' },
  { screen: 'board-empty', path: '/board-empty.html' },
  { screen: 'board-dialog', path: '/board-dialog.html' },
]

try {
  for (const theme of ['light', 'dark']) {
    for (const viewport of viewports) {
      const page = await browser.newPage()
      await page.setViewport({ width: viewport.width, height: viewport.height, deviceScaleFactor: 1 })
      await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: theme }])
      await page.evaluateOnNewDocument((nextTheme, key) => {
        try {
          localStorage.setItem(key, nextTheme)
        } catch {
          // ignore
        }
      }, theme, 'lmr-theme')

      for (const target of [...appPages, ...fixturePages]) {
        await page.goto(`${origin}${target.path}`, { waitUntil: 'domcontentloaded', timeout: 30000 })
        await page.waitForFunction(
          (expected) => document.documentElement.getAttribute('data-theme') === expected,
          { timeout: 8000 },
          theme,
        )
        await page.waitForSelector('.auth-card, .legal-shell, .fatal-error, .board-shell', { timeout: 15000 })
        await page.evaluate((nextTheme) => {
          for (const button of document.querySelectorAll('.theme-toggle button')) {
            const label = (button.textContent || '').trim().toLowerCase()
            button.setAttribute('aria-pressed', String(label === nextTheme))
          }
        }, theme)
        await new Promise((resolve) => setTimeout(resolve, 300))
        const prefix = theme === 'light' ? 'before' : 'after'
        const file = join(outDir, `${prefix}_${theme}_${target.screen}_${viewport.name}.png`)
        await page.screenshot({ path: file, fullPage: true })
        console.log(file)
      }
      await page.close()
    }
  }
} finally {
  await browser.close()
  preview.kill('SIGTERM')
}
