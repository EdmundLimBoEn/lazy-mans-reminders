(function () {
  var KEY = 'lmr-theme'
  var LIGHT_THEME_COLOR = '#ffffff'
  var DARK_THEME_COLOR = '#0a0a0a'
  var root = document.documentElement
  var stored = null
  try {
    stored = window.localStorage.getItem(KEY)
  } catch (error) {
    stored = null
  }
  var preference = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system'
  var prefersDark = false
  try {
    prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  } catch (error) {
    prefersDark = false
  }
  var theme = preference === 'light' ? 'light' : preference === 'dark' ? 'dark' : prefersDark ? 'dark' : 'light'
  root.setAttribute('data-theme', theme)
  // shadcn/ui dark tokens live under .dark
  if (theme === 'dark') root.classList.add('dark')
  else root.classList.remove('dark')
  var meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', theme === 'dark' ? DARK_THEME_COLOR : LIGHT_THEME_COLOR)
})()
