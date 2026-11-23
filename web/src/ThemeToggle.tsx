import { useEffect, useState } from 'react'
import { Monitor, Moon, Sun } from 'lucide-react'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import {
  applyResolvedTheme,
  isThemePreference,
  persistPreference,
  prefersDarkScheme,
  readStoredPreference,
  resolveTheme,
  THEME_STORAGE_KEY,
  type ThemePreference,
} from './theme'

const OPTIONS: { value: ThemePreference; label: string; Icon: typeof Sun }[] = [
  { value: 'system', label: 'System', Icon: Monitor },
  { value: 'light', label: 'Light', Icon: Sun },
  { value: 'dark', label: 'Dark', Icon: Moon },
]

export function ThemeToggle() {
  const [preference, setPreference] = useState<ThemePreference>(readStoredPreference)

  useEffect(() => {
    const onStorage = (event: StorageEvent) => {
      if ((event.key === THEME_STORAGE_KEY || event.key === null) && event.storageArea === window.localStorage) {
        setPreference(readStoredPreference())
      }
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  useEffect(() => {
    applyResolvedTheme(resolveTheme(preference, prefersDarkScheme()))
    if (preference !== 'system') return
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => applyResolvedTheme(resolveTheme('system', media.matches))
    media.addEventListener('change', onChange)
    return () => media.removeEventListener('change', onChange)
  }, [preference])

  return (
    <ToggleGroup
      type="single"
      variant="outline"
      size="sm"
      aria-label="Theme"
      value={preference}
      onValueChange={(value) => {
        if (isThemePreference(value)) {
          persistPreference(value)
          setPreference(value)
        }
      }}
    >
      {OPTIONS.map(({ value, label, Icon }) => (
        <ToggleGroupItem
          key={value}
          value={value}
          aria-label={label}
          title={label}
          className="gap-1.5 px-2.5 text-xs text-muted-foreground data-[state=on]:text-foreground"
        >
          <Icon className="size-3.5" aria-hidden="true" />
          <span className="max-sm:sr-only">{label}</span>
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}
