import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const css = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'styles.css'), 'utf8')

type Rgba = { r: number; g: number; b: number; a: number }

const TEXT_PAIRS: [string, string][] = [
  ['--ink', '--paper'],
  ['--ink', '--card'],
  ['--muted', '--paper'],
  ['--muted', '--card'],
  ['--red-text', '--paper'],
  ['--red-text', '--card'],
  ['--danger-text', '--paper'],
  ['--danger-text', '--card'],
  ['--on-accent', '--red'],
  ['--on-accent', '--danger'],
  ['--error-fg', '--error-bg'],
  ['--lede', '--brand-bg'],
  ['--brand-fg', '--brand-bg'],
  ['--done', '--card'],
  ['--paper', '--ink'],
  ['--widget-fg', '--widget-bg'],
  ['--widget-muted', '--widget-bg'],
  ['--oauth-google-fg', '--oauth-google-bg'],
  ['--oauth-apple-fg', '--oauth-apple-bg'],
]

const UI_PAIRS: [string, string][] = [
  ['--focus', '--paper'],
  ['--focus', '--card'],
]

function blockAfter(prelude: string): string {
  const start = css.indexOf(prelude)
  if (start === -1) throw new Error(`Missing CSS prelude: ${prelude}`)
  const open = css.indexOf('{', start)
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

function parseTokens(body: string): Record<string, string> {
  const tokens: Record<string, string> = {}
  for (const line of body.split(';')) {
    const trimmed = line.trim()
    if (!trimmed.startsWith('--')) continue
    const colon = trimmed.indexOf(':')
    tokens[trimmed.slice(0, colon).trim()] = trimmed.slice(colon + 1).trim()
  }
  return tokens
}

function parseHex(value: string): Rgba {
  let hex = value.trim()
  if (!hex.startsWith('#')) throw new Error(`Not a hex color: ${value}`)
  hex = hex.slice(1)
  if (hex.length === 3 || hex.length === 4) {
    hex = hex.split('').map((char) => char + char).join('')
  }
  const r = Number.parseInt(hex.slice(0, 2), 16)
  const g = Number.parseInt(hex.slice(2, 4), 16)
  const b = Number.parseInt(hex.slice(4, 6), 16)
  const a = hex.length >= 8 ? Number.parseInt(hex.slice(6, 8), 16) / 255 : 1
  if ([r, g, b, a].some((channel) => Number.isNaN(channel))) {
    throw new Error(`Invalid hex color: ${value}`)
  }
  return { r, g, b, a }
}

function composite(fg: Rgba, bg: Rgba): Rgba {
  const a = fg.a
  return {
    r: fg.r * a + bg.r * (1 - a),
    g: fg.g * a + bg.g * (1 - a),
    b: fg.b * a + bg.b * (1 - a),
    a: 1,
  }
}

function channel(value: number): number {
  const srgb = value / 255
  return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4
}

function luminance(color: Rgba): number {
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
}

function contrastRatio(fgHex: string, bgHex: string): number {
  const bg = parseHex(bgHex)
  const fg = composite(parseHex(fgHex), bg)
  const opaqueBg = composite(bg, { r: 255, g: 255, b: 255, a: 1 })
  const lighter = Math.max(luminance(fg), luminance(opaqueBg))
  const darker = Math.min(luminance(fg), luminance(opaqueBg))
  return (lighter + 0.05) / (darker + 0.05)
}

function rounded(ratio: number): number {
  return Math.round(ratio * 100) / 100
}

const light = parseTokens(blockAfter(':root'))
const dark = { ...light, ...parseTokens(blockAfter('html[data-theme="dark"]')) }

describe('theme token contrast', () => {
  it('keeps the original light palette', () => {
    expect(light['--ink']).toBe('#24231f')
    expect(light['--paper']).toBe('#f5f1e8')
    expect(light['--card']).toBe('#fffdf8')
    expect(light['--red']).toBe('#b33d2c')
    expect(light['--red-text']).toBe('#b33d2c')
    expect(light['--muted']).toBe('#5f5b53')
    expect(light['--line']).toBe('#ddd7ca')
    expect(light['--danger']).toBe('#a72819')
    expect(light['--danger-text']).toBe('#a72819')
    expect(light['--error-bg']).toBe('#fae2dd')
    expect(light['--error-fg']).toBe('#822516')
    expect(light['--focus']).toBe('#2f68bd')
  })

  it('does not leave hardcoded colors outside the token blocks', () => {
    const rest = css
      .replace(/:root\s*\{[\s\S]*?\n\}/, '')
      .replace(/html\[data-theme="dark"\]\s*\{[\s\S]*?\n\}/, '')
    expect(rest).not.toMatch(/#[0-9A-Fa-f]{3,8}\b/)
  })

  it.each(['light', 'dark'] as const)('%s text/background pairs meet WCAG AA 4.5:1', (theme) => {
    const tokens = theme === 'light' ? light : dark
    const failures: string[] = []
    for (const [fgName, bgName] of TEXT_PAIRS) {
      const fg = tokens[fgName]
      const bg = tokens[bgName]
      if (!fg || !bg) {
        failures.push(`missing ${fgName} or ${bgName}`)
        continue
      }
      const ratio = contrastRatio(fg, bg)
      if (rounded(ratio) < 4.5) {
        failures.push(`${fgName} on ${bgName} ${fg} / ${bg} = ${ratio.toFixed(2)}`)
      }
    }
    expect(failures).toEqual([])
  })

  it.each(['light', 'dark'] as const)('%s focus rings meet WCAG AA 3:1 against surfaces', (theme) => {
    const tokens = theme === 'light' ? light : dark
    const failures: string[] = []
    for (const [fgName, bgName] of UI_PAIRS) {
      const ratio = contrastRatio(tokens[fgName], tokens[bgName])
      if (rounded(ratio) < 3) {
        failures.push(`${fgName} on ${bgName} = ${ratio.toFixed(2)}`)
      }
    }
    expect(failures).toEqual([])
  })
})
