import { readFileSync, writeFileSync } from 'node:fs'

const provider = new URL(import.meta.resolve('@cloudflare/workers-oauth-provider'))
const source = readFileSync(provider, 'utf8')
let patched = source

function replace(before, after, name) {
  if (patched.includes(after)) return
  if (patched.split(before).length !== 2) {
    throw new Error(`Review the ${name} patch for this OAuth provider version`)
  }
  patched = patched.replace(before, after)
}

// The provider warns directly before its onError hook can handle a metadata failure.
replace([
  '} catch (error) {',
  '\t\t\t\tconsole.warn(`CIMD fetch failed for ${clientId}:`, error instanceof Error ? error.message : error);',
  '\t\t\t\tthrow new CimdFetchError(clientId, error);',
].join('\n'), [
  '} catch {',
  '\t\t\t\tconst failure = new CimdFetchError("[redacted]", "metadata_resolution_failed");',
  '\t\t\t\tconsole.warn(failure.reason);',
  '\t\t\t\tthrow failure;',
].join('\n'), 'client metadata diagnostic')

const corsHeaders = `
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS, DELETE",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept, MCP-Protocol-Version",`

// Preserve the Worker's retry response when the provider reads the code's grant.
const grantRead = '\t\tconst grantData = await env.OAUTH_KV.get(grantKey, { type: "json" });'
const missingGrant = '\t\tif (!grantData) return this.createErrorResponse("invalid_grant", { description: "Grant not found or authorization code expired" });'
replace(`${grantRead}\n${missingGrant}`, `\t\tlet grantData;
    try {
      grantData = await env.OAUTH_KV.get(grantKey, { type: "json" });
    } catch (error) {
      const rateLimited = (error instanceof OAuthError && error.statusCode === 429) ||
        (error instanceof Error && /429 Too Many Requests/i.test(error.message));
      return this.createErrorResponse("temporarily_unavailable", {
        description: "Token issuance is temporarily unavailable; retry shortly",
        statusCode: rateLimited ? 429 : 503,
        headers: {${corsHeaders}
          "Retry-After": "30",
          "Access-Control-Expose-Headers": "Retry-After",
        },
      });
    }
${missingGrant}`, 'authorization code grant read')

// Consumed grants have no PKCE challenge. Preserve the provider's replay
// revocation for the original redirect and give both variants the same error.
const replay = '\t\tif (!grantData.authCodeWrappedKey) {'
const revokeReplay = [
  '\t\t\ttry {',
  '\t\t\t\tawait this.createOAuthHelpers(env).revokeGrant(grantId, userId);',
  '\t\t\t} catch {}',
].join('\n')
replace(`${replay}\n${revokeReplay}`, `${replay}
      if (grantData.redirectUri && redirectUri === grantData.redirectUri) {
${revokeReplay.replace(/^/gm, '\t')}
      }`, 'authorization code replay')

// Check the issuing redirect against the same grant the provider validated.
// Defer both redirect checks until after PKCE and before writes or callbacks.
const registeredRedirect = '\t\tif (redirectUri && !isValidRedirectUri(redirectUri, clientInfo.redirectUris)) return this.createErrorResponse("invalid_grant", { description: "Invalid redirect URI" });'
const redirectBeforePkce = [
  '\t\tif (!redirectUri && !isPkceEnabled) return this.createErrorResponse("invalid_request", { description: "redirect_uri is required when not using PKCE" });',
  registeredRedirect,
  '\t\tif (!isPkceEnabled && codeVerifier) return this.createErrorResponse("invalid_request", { description: "code_verifier provided for a flow that did not use PKCE" });',
]
const pkceEnd = [
  '\t\t\tif (calculatedChallenge !== grantData.codeChallenge) return this.createErrorResponse("invalid_grant", { description: "Invalid PKCE code_verifier" });',
  '\t\t}',
].join('\n')
const redirectAfterPkce = `${pkceEnd}
    if (!grantData.redirectUri || redirectUri !== grantData.redirectUri) {
      return this.createErrorResponse("invalid_grant", {
        description: "Redirect URI does not match the authorization request",
        headers: {${corsHeaders}
        },
      });
    }
${registeredRedirect}`
if (!patched.includes(redirectAfterPkce)) {
  replace(`${redirectBeforePkce.join('\n')}\n`, redirectBeforePkce[2] + '\n', 'pre-PKCE redirect checks')
  replace(pkceEnd, redirectAfterPkce, 'authorization code redirect validation')
}

if (patched !== source) writeFileSync(provider, patched)
