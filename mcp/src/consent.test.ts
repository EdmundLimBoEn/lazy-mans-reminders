import { describe, expect, it } from 'vitest'
import { displayName } from './consent'

describe('displayName', () => {
  it('does not split an emoji crossing the truncation cutoff', () => {
    expect(displayName(`${'a'.repeat(78)}😀x`)).toBe(`${'a'.repeat(78)}…`)
    expect(displayName('😀'.repeat(41))).toBe(`${'😀'.repeat(39)}…`)
  })

  it('keeps a complete emoji immediately before the cutoff', () => {
    expect(displayName(`${'a'.repeat(77)}😀xx`)).toBe(`${'a'.repeat(77)}😀…`)
  })

  it('preserves names at the existing limit and ASCII truncation', () => {
    const name = `${'a'.repeat(78)}😀`
    expect(displayName(name)).toBe(name)
    expect(displayName('a'.repeat(81))).toBe(`${'a'.repeat(79)}…`)
  })
})
