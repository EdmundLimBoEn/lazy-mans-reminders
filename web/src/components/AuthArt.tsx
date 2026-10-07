import { Square } from 'lucide-react'

/** Monochrome lock-screen preview for the sign-in page (decorative). */
export function PhonePreview() {
  return (
    <div className="relative hidden h-72 w-64 overflow-hidden lg:block" aria-hidden="true">
      <div className="absolute inset-x-0 top-0 h-[26rem] rounded-[2.75rem] border bg-card p-3 shadow-sm">
        <div className="flex h-full flex-col rounded-[2.25rem] border bg-muted/40 px-4 pt-3">
          <div className="mx-auto h-6 w-20 rounded-full bg-foreground" />
          <p className="mt-8 text-center text-5xl font-light tracking-tight tabular-nums">9:41</p>
          <div className="mt-8 rounded-xl border bg-background/80 p-3 text-xs">
            <span className="text-[0.625rem] font-medium tracking-wider text-muted-foreground">REMINDERS</span>
            <p className="mt-2 flex items-center gap-1.5"><Square className="size-3 text-muted-foreground" /> Book dentist</p>
            <p className="mt-1.5 flex items-center gap-1.5"><Square className="size-3 text-muted-foreground" /> Send the invoice</p>
          </div>
        </div>
      </div>
      <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-b from-transparent to-background" />
    </div>
  )
}

export function AppleLogo() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"
        fill="currentColor"
      />
    </svg>
  )
}

export function GoogleLogo() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M12.48 10.92v3.28h7.84c-.24 1.84-.853 3.187-1.787 4.133-1.147 1.147-2.933 2.4-6.053 2.4-4.827 0-8.6-3.893-8.6-8.72s3.773-8.72 8.6-8.72c2.6 0 4.507 1.027 5.907 2.347l2.307-2.307C18.747 1.44 16.133 0 12.48 0 5.867 0 .307 5.387.307 12s5.56 12 12.173 12c3.573 0 6.267-1.173 8.373-3.36 2.16-2.16 2.84-5.213 2.84-7.667 0-.76-.053-1.467-.173-2.053H12.48z"
        fill="currentColor"
      />
    </svg>
  )
}
