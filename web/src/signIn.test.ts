import { beforeEach, expect, it, vi } from 'vitest'
import type { FormEvent, ReactElement, ReactNode } from 'react'
import { SignIn } from './App'

const hooks = vi.hoisted(() => ({ states: [] as unknown[], cursor: 0 }))
const auth = vi.hoisted(() => ({
  signInWithOtp: vi.fn(),
  signInWithOAuth: vi.fn(),
}))
vi.mock('./supabase', () => ({ supabase: { auth } }))
vi.mock('./ThemeToggle', () => ({ ThemeToggle: () => null }))
vi.mock('./legalFooter', () => ({ LegalFooterLinks: () => null }))
vi.mock('@/components/SiteHeader', () => ({ SiteHeader: ({ children }: { children?: ReactNode }) => children ?? null }))
vi.mock('@/components/AuthArt', () => ({
  AppleLogo: () => null,
  GoogleLogo: () => null,
  PhonePreview: () => null,
}))
vi.mock('react', async original => ({
  ...await original<typeof import('react')>(),
  useState: (initial: unknown) => {
    const index = hooks.cursor++
    if (!(index in hooks.states)) hooks.states[index] = initial
    return [hooks.states[index], (value: unknown) => { hooks.states[index] = value }]
  },
  useRef: (current: unknown) => ({ current }),
  useMemo: (compute: () => unknown) => compute(),
  useCallback: (callback: unknown) => callback,
  useEffect: () => {},
}))

type Props = {
  children?: ReactNode
  onSubmit?: (event: FormEvent) => unknown
  onClick?: () => unknown
  disabled?: boolean
  role?: string
}
function nodes(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(nodes)
  if (!node || typeof node !== 'object' || !('props' in node)) return []
  const element = node as ReactElement<Props>
  return [element, ...nodes(element.props.children)]
}

function render() {
  hooks.cursor = 0
  return nodes(SignIn({ onNavigate: vi.fn() }))
}

function setEmail(value: string) {
  const input = render().find(node => node.props && 'id' in node.props && node.props.id === 'email')
  ;(input!.props as { onChange: (event: { target: { value: string } }) => void })
    .onChange({ target: { value } })
}

beforeEach(() => {
  hooks.states = []
  vi.resetAllMocks()
  vi.stubGlobal('window', { location: { href: 'https://np.sillyapps.co/', origin: 'https://np.sillyapps.co' } })
  vi.stubGlobal('sessionStorage', { getItem: () => null, setItem: () => {}, removeItem: () => {} })
})

it('enables the sign-in button after signInWithOtp rejects', async () => {
  auth.signInWithOtp.mockRejectedValue(
    new DOMException('The quota has been exceeded.', 'QuotaExceededError'),
  )
  setEmail('you@example.com')
  const form = render().find(node => node.props.onSubmit)!
  void form.props.onSubmit!({ preventDefault() {} } as FormEvent)
  await vi.waitFor(() => {
    const tree = render()
    expect(tree.some(node => node.props.role === 'alert' && node.props.children === 'The quota has been exceeded.')).toBe(true)
    const submit = tree.find(node => node.props.disabled !== undefined && nodes(node).some(child => child.props.children === 'Send sign-in link'))
    expect(submit?.props.disabled).toBe(false)
  })
})
