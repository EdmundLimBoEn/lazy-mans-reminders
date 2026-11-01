import { fileURLToPath } from 'node:url'
import { build } from 'vite'
import type { OutputChunk } from 'rollup'
import { expect, it } from 'vitest'

it('keeps board code and drag-and-drop packages behind a dynamic import', async () => {
  // Inspect the actual production chunk graph, including transitive static imports.
  const result = await build({
    root: fileURLToPath(new URL('..', import.meta.url)),
    logLevel: 'silent',
    build: { write: false },
  })
  const outputs = Array.isArray(result) ? result : [result]
  const chunks = outputs.flatMap(output => 'output' in output ? output.output : [])
    .filter((output): output is OutputChunk => output.type === 'chunk')
  const entry = chunks.find(chunk => chunk.isEntry)!
  expect(entry).toBeDefined()
  const byName = new Map(chunks.map(chunk => [chunk.fileName, chunk]))
  function reachable(start: OutputChunk, dynamic: boolean): Set<OutputChunk> {
    const visited = new Set<OutputChunk>()
    function visit(chunk: OutputChunk) {
      if (visited.has(chunk)) return
      visited.add(chunk)
      for (const name of [...chunk.imports, ...(dynamic ? chunk.dynamicImports : [])]) {
        const dependency = byName.get(name)
        if (dependency) visit(dependency)
      }
    }
    visit(start)
    return visited
  }
  const initialModules = [...reachable(entry, false)].flatMap(chunk => Object.keys(chunk.modules))
  const allModules = [...reachable(entry, true)].flatMap(chunk => Object.keys(chunk.modules))
  for (const module of [
    '/node_modules/@dnd-kit/core/', '/node_modules/@dnd-kit/sortable/', '/node_modules/@dnd-kit/utilities/',
    '/src/Board.tsx', '/src/RoutineReminders.tsx', '/src/ConnectedAgents.tsx',
    '/src/components/SortableReminder.tsx', '/src/lib/accountExport.ts',
  ]) {
    expect(initialModules.filter(id => id.includes(module)), module).toEqual([])
    expect(allModules.some(id => id.includes(module)), module).toBe(true)
  }
}, 60_000)
