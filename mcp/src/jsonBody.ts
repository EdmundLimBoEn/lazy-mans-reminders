const MAX_JSON_BYTES = 16 * 1024

/** Parse JSON only after counting the actual streamed bytes. */
export async function readJsonBody(request: Request): Promise<unknown> {
  const reader = request.body?.getReader()
  const bytes = new Uint8Array(MAX_JSON_BYTES)
  let length = 0
  if (reader) {
    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        if (length + value.byteLength > MAX_JSON_BYTES) {
          // Cancellation must not delay the rejection or turn it into a parse error.
          void reader.cancel().catch(() => {})
          return new Response(JSON.stringify({ error: 'invalid_body' }), {
            status: 413,
            headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
          })
        }
        bytes.set(value, length)
        length += value.byteLength
      }
    } finally {
      reader.releaseLock()
    }
  }
  return JSON.parse(new TextDecoder().decode(bytes.subarray(0, length)))
}
