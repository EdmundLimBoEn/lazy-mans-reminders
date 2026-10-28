// Keep one background read in flight and retain one refresh requested while it
// runs: that read may have started before the connection recovered.
export function connectionRefresh(load: () => Promise<void>, onError: (error: unknown) => void) {
  let running = false
  let pending = false
  let disposed = false

  async function run() {
    running = true
    do {
      pending = false
      try {
        await load()
      } catch (error) {
        if (!disposed) onError(error)
      }
    } while (pending && !disposed)
    running = false
  }

  function refresh() {
    if (disposed) return
    if (running) pending = true
    else void run()
  }

  window.addEventListener('online', refresh)
  refresh()
  return {
    refresh,
    onStatus(status: string) {
      if (status === 'SUBSCRIBED') refresh()
    },
    dispose() {
      disposed = true
      window.removeEventListener('online', refresh)
    },
  }
}
