import { describe, expect, it } from 'vitest'
import { normalizePath } from './routing'

describe('normalizePath', () => {
  it('keeps known legal routes', () => {
    expect(normalizePath('/privacy')).toBe('/privacy')
    expect(normalizePath('/terms')).toBe('/terms')
    expect(normalizePath('/support')).toBe('/support')
  })

  it('strips trailing slashes', () => {
    expect(normalizePath('/privacy/')).toBe('/privacy')
    expect(normalizePath('/terms///')).toBe('/terms')
  })

  it('maps root and empty to /', () => {
    expect(normalizePath('/')).toBe('/')
    expect(normalizePath('')).toBe('/')
    expect(normalizePath('///')).toBe('/')
  })

  it('maps unknown paths to /', () => {
    expect(normalizePath('/board')).toBe('/')
    expect(normalizePath('/privacy/extra')).toBe('/')
    expect(normalizePath('/auth/callback')).toBe('/')
  })
})
