import type { AriaRole, ReactNode } from 'react'
import { LegalFooterLinks } from '@/LegalPages'
import { SiteHeader } from '@/components/SiteHeader'
import { ThemeToggle } from '@/ThemeToggle'

/** Centered, single-message page: 404, auth errors, iOS hand-off. */
export function StatusShell({
  title,
  role,
  onNavigate,
  children,
}: {
  title: string
  role?: AriaRole
  onNavigate: (path: string) => void
  children: ReactNode
}) {
  return (
    <div className="mx-auto flex min-h-svh w-full max-w-5xl flex-col px-4 sm:px-6">
      <SiteHeader onNavigate={onNavigate}>
        <ThemeToggle />
      </SiteHeader>
      <main role={role} className="flex flex-1 items-center justify-center py-16">
        <div className="flex w-full max-w-sm flex-col items-start gap-3">
          <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
          {children}
        </div>
      </main>
      <footer className="flex justify-center pb-8">
        <LegalFooterLinks onNavigate={onNavigate} />
      </footer>
    </div>
  )
}

export function StatusText({ children }: { children: ReactNode }) {
  return <p className="text-sm leading-relaxed text-muted-foreground [overflow-wrap:anywhere]">{children}</p>
}
