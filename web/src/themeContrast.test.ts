import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { THEME_COLOR } from './theme'

const dir = dirname(fileURLToPath(import.meta.url))
const css = readFileSync(join(dir, 'styles.css'), 'utf8')

type Rgba = { r: number; g: number; b: number; a: number }
type Tokens = Record<string, string>
/** A colour reference: a token name, a literal, optionally at an alpha ("--destructive/60"). */
type Ref = string

function blockAfter(prelude: RegExp): string {
  const match = prelude.exec(css)
  if (!match) throw new Error(`Missing CSS block: ${prelude}`)
  const open = css.indexOf('{', match.index)
  let depth = 0
  for (let i = open; i < css.length; i += 1) {
    if (css[i] === '{') depth += 1
    else if (css[i] === '}') {
      depth -= 1
      if (depth === 0) return css.slice(open + 1, i)
    }
  }
  throw new Error(`Unclosed CSS block: ${prelude}`)
}

function parseTokens(body: string): Tokens {
  const tokens: Tokens = {}
  for (const line of body.replace(/\/\*[\s\S]*?\*\//g, '').split(';')) {
    const trimmed = line.trim()
    if (!trimmed.startsWith('--')) continue
    const colon = trimmed.indexOf(':')
    tokens[trimmed.slice(0, colon).trim()] = trimmed.slice(colon + 1).trim()
  }
  return tokens
}

const light = parseTokens(blockAfter(/^:root\s*\{/m))
const dark = { ...light, ...parseTokens(blockAfter(/^\.dark\s*\{/m)) }

/** OKLCH (CSS Color 4) → gamma-encoded sRGB 0–255, clamped. */
function oklchToRgba(value: string): Rgba {
  const match = /^oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*(?:\/\s*([\d.]+)(%?))?\s*\)$/.exec(value)
  if (!match) throw new Error(`Not an oklch() colour: ${value}`)
  const [L, C, H] = [Number(match[1]), Number(match[2]), Number(match[3])]
  const alpha = match[4] === undefined ? 1 : Number(match[4]) / (match[5] ? 100 : 1)
  const a = C * Math.cos((H * Math.PI) / 180)
  const b = C * Math.sin((H * Math.PI) / 180)
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3
  const linear = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ]
  const [r, g, bl] = linear.map((x) => {
    const v = Math.min(1, Math.max(0, x))
    return Math.round((v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055) * 255)
  })
  return { r, g, b: bl, a: alpha }
}

function hexToRgba(value: string): Rgba {
  const hex = value.slice(1)
  const full = hex.length <= 4 ? hex.split('').map((c) => c + c).join('') : hex
  return {
    r: Number.parseInt(full.slice(0, 2), 16),
    g: Number.parseInt(full.slice(2, 4), 16),
    b: Number.parseInt(full.slice(4, 6), 16),
    a: full.length === 8 ? Number.parseInt(full.slice(6, 8), 16) / 255 : 1,
  }
}

function toHex({ r, g, b }: Rgba): string {
  return `#${[r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('')}`
}

function resolve(ref: Ref, tokens: Tokens): Rgba {
  const [name, pct] = ref.split('/')
  const raw = name.startsWith('--') ? tokens[name] : name
  if (!raw) throw new Error(`Unknown token ${name}`)
  const color = raw.startsWith('#') ? hexToRgba(raw) : oklchToRgba(raw)
  return pct ? { ...color, a: color.a * (Number(pct) / 100) } : color
}

function over(fg: Rgba, bg: Rgba): Rgba {
  return {
    r: fg.r * fg.a + bg.r * (1 - fg.a),
    g: fg.g * fg.a + bg.g * (1 - fg.a),
    b: fg.b * fg.a + bg.b * (1 - fg.a),
    a: 1,
  }
}

function luminance({ r, g, b }: Rgba): number {
  const ch = (v: number) => {
    const s = v / 255
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
}

/** Contrast of fg on bg, where a translucent bg is first laid over `surface`. */
function contrast(tokens: Tokens, fgRef: Ref, bgRef: Ref, surfaceRef: Ref = '--background'): number {
  const surface = resolve(surfaceRef, tokens)
  const bg = over(resolve(bgRef, tokens), surface)
  const fg = over(resolve(fgRef, tokens), bg)
  const [hi, lo] = [luminance(fg), luminance(bg)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}

// [foreground, background, surface under a translucent background]
type Pair = [Ref, Ref, Ref?]

const TEXT_PAIRS: Pair[] = [
  ['--foreground', '--background'],
  ['--card-foreground', '--card'],
  ['--popover-foreground', '--popover'],
  ['--primary-foreground', '--primary'],
  ['--secondary-foreground', '--secondary'],
  ['--accent-foreground', '--accent'],
  ['--muted-foreground', '--background'],
  ['--muted-foreground', '--card'],
  ['--foreground', '--muted'], // code and pre blocks
  ['--destructive', '--background'], // inline form errors
  ['--destructive', '--card'], // destructive Alert title / icon
  ['--destructive/90', '--card'], // destructive Alert description
]

// Button variant="destructive": white text; dark mode uses bg-destructive/60.
const DESTRUCTIVE_BUTTON: Record<'light' | 'dark', Pair> = {
  light: ['#ffffff', '--destructive'],
  dark: ['#ffffff', '--destructive/60', '--background'],
}

const FOCUS_PAIRS: Pair[] = [
  ['--ring', '--background'],
  ['--ring', '--card'],
  ['--ring', '--popover'],
]

describe('theme tokens (shadcn/ui neutral)', () => {
  it('starts from the official shadcn neutral values', () => {
    expect(light['--background']).toBe('oklch(1 0 0)')
    expect(light['--foreground']).toBe('oklch(0.145 0 0)')
    expect(light['--primary']).toBe('oklch(0.205 0 0)')
    expect(light['--muted-foreground']).toBe('oklch(0.556 0 0)')
    expect(dark['--background']).toBe('oklch(0.145 0 0)')
    expect(dark['--card']).toBe('oklch(0.205 0 0)')
    expect(dark['--primary']).toBe('oklch(0.922 0 0)')
    expect(dark['--destructive']).toBe('oklch(0.704 0.191 22.216)')
  })

  it('uses the page background as the browser theme-color in both themes', () => {
    expect(toHex(resolve('--background', light))).toBe(THEME_COLOR.light)
    expect(toHex(resolve('--background', dark))).toBe(THEME_COLOR.dark)
  })

  it('maps Tailwind dark: to the .dark class that theme-init.js sets', () => {
    expect(css).toMatch(/@custom-variant dark \(&:is\(\.dark \*\)\);/)
    const init = readFileSync(join(dir, '../public/theme-init.js'), 'utf8')
    expect(init).toMatch(/classList\.add\('dark'\)/)
  })

  it('keeps colour literals inside the :root and .dark token blocks', () => {
    const rest = css
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/^:root\s*\{[\s\S]*?\n\}/m, '')
      .replace(/^\.dark\s*\{[\s\S]*?\n\}/m, '')
    expect(rest).not.toMatch(/#[0-9a-f]{3,8}\b|oklch\(|rgba?\(|hsla?\(/i)
  })

  it.each(['light', 'dark'] as const)('%s text pairs meet WCAG AA 4.5:1', (theme) => {
    const tokens = theme === 'light' ? light : dark
    const failures = [...TEXT_PAIRS, DESTRUCTIVE_BUTTON[theme]]
      .map(([fg, bg, surface]) => ({ fg, bg, ratio: contrast(tokens, fg, bg, surface) }))
      .filter(({ ratio }) => Math.round(ratio * 100) / 100 < 4.5)
      .map(({ fg, bg, ratio }) => `${fg} on ${bg} = ${ratio.toFixed(2)}`)
    expect(failures).toEqual([])
  })

  it.each(['light', 'dark'] as const)('%s focus ring meets WCAG 3:1 against surfaces', (theme) => {
    const tokens = theme === 'light' ? light : dark
    const failures = FOCUS_PAIRS
      .map(([fg, bg]) => ({ fg, bg, ratio: contrast(tokens, fg, bg) }))
      .filter(({ ratio }) => Math.round(ratio * 100) / 100 < 3)
      .map(({ fg, bg, ratio }) => `${fg} on ${bg} = ${ratio.toFixed(2)}`)
    expect(failures).toEqual([])
  })
})
