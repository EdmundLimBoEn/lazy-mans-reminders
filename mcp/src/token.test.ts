import { describe, expect, it } from 'vitest'
import { hashSecret, parsePresentedToken, secretsEqual } from './token'
import type { TokenSecret } from './domain'

describe('parsePresentedToken', () => {
  it('parses lmr_<uuid>_<secret>', () => {
    const parsed = parsePresentedToken(
      'lmr_550e8400-e29b-41d4-a716-446655440000_abcDEF123_-x',
    )
    expect(parsed).toEqual({
      tokenId: '550e8400-e29b-41d4-a716-446655440000',
      secret: 'abcDEF123_-x',
    })
  })

  it('lowercases the uuid', () => {
    const parsed = parsePresentedToken(
      'lmr_550E8400-E29B-41D4-A716-446655440000_secretvalue',
    )
    expect(parsed?.tokenId).toBe('550e8400-e29b-41d4-a716-446655440000')
  })

  it('rejects missing prefix, bad uuid, or empty secret', () => {
    expect(parsePresentedToken('550e8400-e29b-41d4-a716-446655440000_abc')).toBeNull()
    expect(parsePresentedToken('lmr_not-a-uuid_abc')).toBeNull()
    expect(parsePresentedToken('lmr_550e8400-e29b-41d4-a716-446655440000_')).toBeNull()
    expect(parsePresentedToken('lmr_550e8400-e29b-41d4-a716-446655440000_has.dot')).toBeNull()
  })
})

describe('hashSecret', () => {
  it('SHA-256 hex matches a known digest and compares equal', async () => {
    const hash = await hashSecret('abc' as TokenSecret)
    expect(hash).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    expect(secretsEqual(hash, hash)).toBe(true)
    const other = await hashSecret('abd' as TokenSecret)
    expect(secretsEqual(hash, other)).toBe(false)
  })
})
