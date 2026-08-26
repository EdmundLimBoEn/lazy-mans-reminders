import type { PresentedToken, TokenHash, TokenId, TokenSecret } from './domain'

const TOKEN = /^lmr_([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})_(.+)$/

export function parsePresentedToken(raw: string): PresentedToken | null {
  const match = TOKEN.exec(raw.trim())
  if (!match) return null
  const secret = match[2]
  if (!secret || !/^[A-Za-z0-9_-]+$/.test(secret)) return null
  return {
    tokenId: match[1].toLowerCase() as TokenId,
    secret: secret as TokenSecret,
  }
}

export async function hashSecret(secret: TokenSecret): Promise<TokenHash> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret))
  return hexFromBytes(new Uint8Array(digest)) as TokenHash
}

export function secretsEqual(left: TokenHash, right: TokenHash): boolean {
  const a = hexToBytes(left)
  const b = hexToBytes(right)
  if (a.byteLength !== b.byteLength) return false
  let diff = 0
  for (let i = 0; i < a.byteLength; i += 1) diff |= a[i]! ^ b[i]!
  return diff === 0
}

function hexFromBytes(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

function hexToBytes(hex: string): Uint8Array {
  const normalized = hex.toLowerCase()
  if (normalized.length % 2 !== 0 || /[^0-9a-f]/.test(normalized)) {
    return new Uint8Array()
  }
  const bytes = new Uint8Array(normalized.length / 2)
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(normalized.slice(i * 2, i * 2 + 2), 16)
  }
  return bytes
}
