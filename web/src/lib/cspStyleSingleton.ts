// Drop-in for `react-style-singleton` (used by react-remove-scroll inside Radix Dialog /
// AlertDialog). The original appends a <style> element, which CSP `style-src 'self'`
// blocks. Constructable stylesheets adopted by the document are CSSOM, not inline
// markup, so they apply under the strict CSP. Same API: add on first use, remove on last.
import { useEffect } from 'react'

type Sheet = { add: (style: string) => void; remove: () => void }

export const stylesheetSingleton = (): Sheet => {
  let counter = 0
  let sheet: CSSStyleSheet | null = null
  return {
    add(style: string) {
      if (counter === 0 && typeof document !== 'undefined') {
        sheet = new CSSStyleSheet()
        sheet.replaceSync(style)
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
      }
      counter += 1
    },
    remove() {
      counter -= 1
      if (counter === 0 && sheet) {
        const current = sheet
        document.adoptedStyleSheets = document.adoptedStyleSheets.filter((item) => item !== current)
        sheet = null
      }
    },
  }
}

export const styleHookSingleton = () => {
  const sheet = stylesheetSingleton()
  return (styles: string, isDynamic?: boolean) => {
    // Same dependency list as the original package.
    const dynamicKey = styles && isDynamic
    useEffect(() => {
      sheet.add(styles)
      return () => sheet.remove()
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [dynamicKey])
  }
}

export const styleSingleton = () => {
  const useStyle = styleHookSingleton()
  const Sheet = ({ styles, dynamic }: { styles: string; dynamic?: boolean }) => {
    useStyle(styles, dynamic)
    return null
  }
  return Sheet
}
