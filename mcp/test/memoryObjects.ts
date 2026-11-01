export function memoryState(): DurableObjectState {
  const entries = new Map<string, unknown>()
  let queue = Promise.resolve()
  const serialize = <T>(callback: () => Promise<T>): Promise<T> => {
    const result = queue.then(callback)
    queue = result.then(() => {}, () => {})
    return result
  }
  const storage = {
    get: async (key: string) => structuredClone(entries.get(key)),
    put: async (key: string, value: unknown) => { entries.set(key, structuredClone(value)) },
    delete: async (key: string) => entries.delete(key),
    setAlarm: async () => {},
    transaction: <T>(fn: (store: unknown) => Promise<T>) => serialize(() => fn(storage)),
  }
  return { storage, blockConcurrencyWhile: serialize } as unknown as DurableObjectState
}

export function memoryObjects(create: (state: DurableObjectState) => DurableObject): DurableObjectNamespace {
  const objects = new Map<string, DurableObject>()
  return {
    idFromName: (name: string) => name,
    get: (id: string) => {
      if (!objects.has(id)) objects.set(id, create(memoryState()))
      return { fetch: (input: string, init?: RequestInit) => objects.get(id)!.fetch!(new Request(input, init)) }
    },
  } as unknown as DurableObjectNamespace
}
