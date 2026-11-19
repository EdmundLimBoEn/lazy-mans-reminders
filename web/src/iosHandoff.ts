export const IOS_APP_CALLBACK = 'lazymansreminders://auth/callback'

const NATIVE_AUTH_CALLBACK_PARAMS = new Set([
  'code',
  'type',
  'sb',
  'sb_flow_id',
  'error',
  'error_code',
  'error_description',
])

export type IosHandoff =
  | { status: 'open'; href: string }
  | { status: 'error'; message: string }
  | { status: 'empty' }

function firstParam(params: URLSearchParams[], name: string): string | null {
  for (const group of params) {
    const value = group.get(name)
    if (value) return value.replace(/\+/g, ' ')
  }
  return null
}

function takeAllowed(
  source: URLSearchParams,
  dest: URLSearchParams,
  seen: Set<string>,
): boolean {
  for (const [key, value] of source) {
    if (!NATIVE_AUTH_CALLBACK_PARAMS.has(key)) continue
    if (seen.has(key)) return false
    seen.add(key)
    dest.append(key, value)
  }
  return true
}

export function iosHandoffFromLocation(href: string): IosHandoff {
  const url = new URL(href)
  const search = new URLSearchParams(url.search)
  const hash = new URLSearchParams(url.hash.startsWith('#') ? url.hash.slice(1) : '')
  const groups = [search, hash]
  const error = firstParam(groups, 'error_description') || firstParam(groups, 'error')
  if (error) return { status: 'error', message: error }

  const nextSearch = new URLSearchParams()
  const nextHash = new URLSearchParams()
  const seen = new Set<string>()
  if (!takeAllowed(search, nextSearch, seen) || !takeAllowed(hash, nextHash, seen)) {
    return { status: 'empty' }
  }
  const query = nextSearch.toString()
  const fragment = nextHash.toString()
  if (!query && !fragment) return { status: 'empty' }

  return {
    status: 'open',
    href: `${IOS_APP_CALLBACK}${query ? `?${query}` : ''}${fragment ? `#${fragment}` : ''}`,
  }
}
