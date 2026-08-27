export const IOS_APP_CALLBACK = 'lazymansreminders://auth/callback'

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

/** Map an HTTPS magic-link landing URL onto the iOS custom-scheme callback. */
export function iosHandoffFromLocation(href: string): IosHandoff {
  const url = new URL(href)
  const search = new URLSearchParams(url.search)
  const hash = new URLSearchParams(url.hash.startsWith('#') ? url.hash.slice(1) : '')
  const groups = [search, hash]
  const error = firstParam(groups, 'error_description') || firstParam(groups, 'error')
  if (error) return { status: 'error', message: error }

  const hasQuery = [...search.keys()].length > 0
  const hasHash = [...hash.keys()].length > 0
  if (!hasQuery && !hasHash) return { status: 'empty' }

  const next = new URL(IOS_APP_CALLBACK)
  search.forEach((value, key) => next.searchParams.append(key, value))
  return {
    status: 'open',
    href: `${IOS_APP_CALLBACK}${next.search}${url.hash}`,
  }
}
