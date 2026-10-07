import { BrandMark } from '@/components/SiteHeader'

export function Splash({ label }: { label: string }) {
  return (
    <div className="splash grid min-h-svh place-items-center" role="status" aria-label={label}>
      <BrandMark className="size-9 animate-pulse text-xs" />
    </div>
  )
}
