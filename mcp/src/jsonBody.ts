const MAX_JSON_BYTES = 16 * 1024

/** Buffer only up to the limit, counting actual streamed bytes regardless of Content-Length. */
export async function readBodyBytes(request: Request, maxBytes: number): Promise<Uint8Array | Response> {
  const reader = request.body?.getReader()
  const bytes = new Uint8Array(maxBytes)
  let length = 0
  if (reader) {
    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        if (length + value.byteLength > maxBytes) {
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
  return bytes.subarray(0, length)
}

/** Parse JSON only after counting the actual streamed bytes. */
export async function readJsonBody(request: Request): Promise<unknown> {
  const bytes = await readBodyBytes(request, MAX_JSON_BYTES)
  if (bytes instanceof Response) return bytes
  return JSON.parse(new TextDecoder().decode(bytes))
}
