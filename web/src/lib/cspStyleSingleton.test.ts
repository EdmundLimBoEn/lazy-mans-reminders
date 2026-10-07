import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { stylesheetSingleton } from './cspStyleSingleton'

class FakeSheet {
  text = ''
  replaceSync(text: string) {
    this.text = text
  }
}

describe('CSP-safe react-style-singleton replacement', () => {
  let doc: { adoptedStyleSheets: FakeSheet[]; createElement: ReturnType<typeof vi.fn> }

  beforeEach(() => {
    doc = { adoptedStyleSheets: [], createElement: vi.fn() }
    vi.stubGlobal('document', doc)
    vi.stubGlobal('CSSStyleSheet', FakeSheet)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('adopts one constructable sheet while in use and drops it after the last remove', () => {
    const singleton = stylesheetSingleton()
    singleton.add('body { overflow: hidden }')
    singleton.add('body { overflow: hidden }')
    expect(doc.adoptedStyleSheets).toHaveLength(1)
    expect(doc.adoptedStyleSheets[0].text).toBe('body { overflow: hidden }')

    singleton.remove()
    expect(doc.adoptedStyleSheets).toHaveLength(1)
    singleton.remove()
    expect(doc.adoptedStyleSheets).toHaveLength(0)
  })

  it('leaves sheets it does not own in place and never creates a <style> element', () => {
    const other = new FakeSheet()
    doc.adoptedStyleSheets = [other]
    const singleton = stylesheetSingleton()
    singleton.add('.x { color: red }')
    singleton.remove()
    expect(doc.adoptedStyleSheets).toEqual([other])
    expect(doc.createElement).not.toHaveBeenCalled()
  })

  it('is what Vite resolves react-style-singleton to', () => {
    const config = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../vite.config.ts'), 'utf8')
    expect(config).toMatch(/find:\s*\/\^react-style-singleton\$\/[\s\S]*?src\/lib\/cspStyleSingleton\.ts/)
  })
})
