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

  it('keeps auth and connect routes', () => {
    expect(normalizePath('/auth/callback')).toBe('/auth/callback')
    expect(normalizePath('/auth/ios')).toBe('/auth/ios')
    expect(normalizePath('/connect')).toBe('/connect')
    expect(normalizePath('/connect/')).toBe('/connect')
  })

  it('treats legal routes as case-insensitive', () => {
    expect(normalizePath('/Privacy')).toBe('/privacy')
    expect(normalizePath('/TERMS/')).toBe('/terms')
  })

  it('maps unknown paths to not-found', () => {
    expect(normalizePath('/board')).toBe('not-found')
    expect(normalizePath('/privacy/extra')).toBe('not-found')
  })
})
