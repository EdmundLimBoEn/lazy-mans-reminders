import type { AuthRequest } from '@cloudflare/workers-oauth-provider'
import { PENDING_AUTH_TTL_SECONDS } from './constants'

type PendingAuthorization = { request: AuthRequest; expiresAt: number }

export class AuthorizationState implements DurableObject {
  constructor(private readonly state: DurableObjectState) {}

  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname
    if (path === '/redeem' && request.method === 'POST') {
      const { attempt } = await request.json<{ attempt: string }>()
      const consumed = await this.state.storage.transaction(async (storage) => {
        if (await storage.get('redeemed')) return false
        await storage.put('redeemed', attempt)
        return true
      })
      // Code claims use separate object IDs and retain their tombstone: a stale
      // KV read or an already validated, delayed exchange must never reopen one.
      return Response.json({ consumed })
    }
    if (path === '/release' && request.method === 'POST') {
      const { attempt } = await request.json<{ attempt: string }>()
      await this.state.storage.transaction(async (storage) => {
        if (await storage.get('redeemed') === attempt) await storage.delete('redeemed')
      })
      return new Response(null, { status: 204 })
    }
    if (path === '/pending' && request.method === 'PUT') {
      const pending = {
        request: await request.json<AuthRequest>(),
        expiresAt: Date.now() + PENDING_AUTH_TTL_SECONDS * 1000,
      }
      const created = await this.state.storage.transaction(async (storage) => {
        if (await storage.get('pending') || await storage.get('consumed')) return false
        await storage.put('pending', pending)
        await storage.setAlarm(pending.expiresAt)
        return true
      })
      return new Response(null, { status: created ? 201 : 409 })
    }
    if (path === '/pending' && request.method === 'GET') {
      const pending = await this.state.storage.get<PendingAuthorization>('pending')
      return Response.json(pending && pending.expiresAt > Date.now() ? pending.request : null)
    }
    if (path === '/restore' && request.method === 'POST') {
      const restored = await this.state.storage.transaction(async (storage) => {
        if (!await storage.get('consumed')) return false
        const held = await storage.get<PendingAuthorization>('held')
        if (!held || held.expiresAt <= Date.now()) return false
        await storage.delete('consumed')
        await storage.delete('held')
        await storage.put('pending', held)
        return true
      })
      return Response.json({ restored })
    }
    if (path !== '/consume' || request.method !== 'POST') return new Response(null, { status: 404 })
    const consumed = await this.state.storage.transaction(async (storage) => {
      const pending = await storage.get<PendingAuthorization>('pending')
      if (!pending || pending.expiresAt <= Date.now() || await storage.get('consumed')) return false
      await storage.delete('pending')
      await storage.put('held', pending)
      await storage.put('consumed', true)
      return true
    })
    return Response.json({ consumed })
  }

  async alarm(): Promise<void> {
    await this.state.storage.deleteAll()
  }
}
