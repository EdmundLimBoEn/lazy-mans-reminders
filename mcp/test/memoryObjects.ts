export function memoryState(): DurableObjectState {
  const entries = new Map<string, unknown>()
  let alarm: number | null = null
  let queue = Promise.resolve()
  const serialize = <T>(callback: () => Promise<T>): Promise<T> => {
    const result = queue.then(callback)
    queue = result.then(() => {}, () => {})
    return result
  }
  const storage = {
    get: async (key: string) => structuredClone(entries.get(key)),
    put: async (key: string, value: unknown) => { entries.set(key, structuredClone(value)) },
    delete: async (key: string | string[]) => {
      if (typeof key === 'string') return entries.delete(key)
      let deleted = 0
      for (const entry of key) {
        if (entries.delete(entry)) deleted += 1
      }
      return deleted
    },
    list: async ({ prefix = '', limit }: DurableObjectListOptions = {}) => {
      const keys = [...entries.keys()].filter((key) => key.startsWith(prefix)).sort().slice(0, limit)
      return new Map(keys.map((key) => [key, structuredClone(entries.get(key))]))
    },
    getAlarm: async () => alarm,
    setAlarm: async (time: number | Date) => { alarm = Number(time) },
    deleteAlarm: async () => { alarm = null },
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
