import { cn } from '@/lib/utils'

export function LegalFooterLinks({
  onNavigate,
  className,
}: {
  onNavigate: (path: string) => void
  className?: string
}) {
  const link = 'underline underline-offset-4 decoration-border hover:text-foreground hover:decoration-current'
  return (
    <nav
      className={cn('legal-footer-links flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-xs text-muted-foreground', className)}
      aria-label="Legal and support"
    >
      <a className={link} href="/privacy" onClick={(e) => { e.preventDefault(); onNavigate('/privacy') }}>Privacy</a>
      <span aria-hidden="true">·</span>
      <a className={link} href="/terms" onClick={(e) => { e.preventDefault(); onNavigate('/terms') }}>Terms</a>
      <span aria-hidden="true">·</span>
      <a className={link} href="/support" onClick={(e) => { e.preventDefault(); onNavigate('/support') }}>Support</a>
    </nav>
  )
}
