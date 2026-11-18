import { readFileSync, writeFileSync } from 'node:fs'

// The provider warns directly before its onError hook can handle a metadata failure.
const provider = new URL(import.meta.resolve('@cloudflare/workers-oauth-provider'))
const source = readFileSync(provider, 'utf8')
const original = [
  '} catch (error) {',
  '\t\t\t\tconsole.warn(`CIMD fetch failed for ${clientId}:`, error instanceof Error ? error.message : error);',
  '\t\t\t\tthrow new CimdFetchError(clientId, error);',
].join('\n')
const redacted = [
  '} catch {',
  '\t\t\t\tconst failure = new CimdFetchError("[redacted]", "metadata_resolution_failed");',
  '\t\t\t\tconsole.warn(failure.reason);',
  '\t\t\t\tthrow failure;',
].join('\n')

if (source.includes(original)) {
  writeFileSync(provider, source.replace(original, redacted))
} else if (!source.includes(redacted)) {
  throw new Error('Review the client metadata diagnostic patch for this OAuth provider version')
}
