import { PENDING_AUTH_TTL_SECONDS } from './constants'

export class AuthorizationState implements DurableObject {
  constructor(private readonly state: DurableObjectState) {}

  async fetch(): Promise<Response> {
    const consumed = await this.state.storage.transaction(async (storage) => {
      if (await storage.get('consumed')) return false
      await storage.put('consumed', true)
      await storage.setAlarm(Date.now() + PENDING_AUTH_TTL_SECONDS * 1000)
      return true
    })
    return Response.json({ consumed })
  }

  async alarm(): Promise<void> {
    await this.state.storage.deleteAll()
  }
}
