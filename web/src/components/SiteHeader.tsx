import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

export function BrandMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'grid size-6 place-items-center rounded-md bg-primary text-[0.625rem] font-semibold tracking-tight text-primary-foreground',
        className,
      )}
    >
      LM
    </span>
  )
}

export function SiteHeader({
  onNavigate,
  children,
  className,
}: {
  onNavigate: (path: string) => void
  children?: ReactNode
  className?: string
}) {
  return (
    <header className={cn('flex h-14 items-center justify-between gap-3', className)}>
      <a
        href="/"
        className="flex items-center gap-2 text-sm font-medium tracking-tight"
        onClick={(event) => {
          event.preventDefault()
          onNavigate('/')
        }}
      >
        <BrandMark />
        <span>Lazy Man's Reminders</span>
      </a>
      <div className="flex items-center gap-1.5">{children}</div>
    </header>
  )
}
