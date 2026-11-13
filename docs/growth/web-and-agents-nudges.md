# Web and agent nudges — PROPOSAL

Owner: Edmund Lim. This is a placement and behavior proposal, not new product copy or an implementation. Edmund writes all user-facing text. Quoted strings below already exist in the repository; missing text is marked explicitly. File references describe the working tree accompanying this proposal. Quotes omit source-code markup and preserve the displayed wording; short excerpts are identified as such.

The web destination is `https://app.notepads.dev`. Agent setup should lead to the web board's existing Agent access section and its MCP instructions. A bare `/connect` URL cannot start authorization: it needs the request opened by an agent (`web/src/Connect.tsx:142–146`). Preserve the sign-in, explicit Allow/Deny, and revocation steps.

## Existing copy inventory

| Surface / purpose | Existing text, verbatim | Source |
| --- | --- | --- |
| Landing header and hero: web action | “Open app” | `landing/index.html:40`, `landing/index.html:47` |
| Landing platform tag | “Web” | `landing/index.html:50` |
| Landing: agent connections | No existing agent/MCP copy. | `landing/index.html` |
| Web sign-in heading | “Your board, everywhere” | `web/src/App.tsx:134` |
| Web sign-in instructions | “Sign in with Apple, Google, or email. No password to remember.” | `web/src/App.tsx:142` |
| Agent sign-in heading | “Sign in to connect this agent” | `web/src/App.tsx:134` |
| Agent sign-in instructions | “Sign in with Apple or Google in this same window, then tap Allow. Email links often open in another app and fail this step.” | `web/src/App.tsx:141` |
| Agent sign-in continuity | “Finish sign-in in the browser that opened. You will return here to tap Allow.” | `web/src/App.tsx:150` |
| Web board: agent section heading | “Agent access” | `web/src/Board.tsx:726` |
| Web board: OAuth explanation, excerpts around the dynamic MCP URL | “Grok, Cursor, Claude, and Codex can finish /connect. Add the plugin or paste” / “, then sign in when asked. That is the usual path. No tokens to copy.” | `web/src/Board.tsx:730–731` |
| Web board: fallback explanation, excerpt before the dynamic header | “For hosts that cannot use OAuth, mint a key under Advanced, then set” | `web/src/Board.tsx:734` |
| Web board: fallback heading and key lifetime | “Advanced: personal keys” / “Shown once. Revoke anytime.” | `web/src/Board.tsx:742`, `web/src/Board.tsx:747` |
| Web board: Grok setup | “Grok Bot: Settings → Plugins → custom connector. Add the URL and sign in when prompted.” | `web/src/Board.tsx:799` |
| Web board: connection management | “Connected agents” / “These finished Allow. Revoke ends that agent’s access to your board.” / “No connected agents.” | `web/src/ConnectedAgents.tsx:70–75` |
| Connect page without an agent request | “Nothing to connect” / “Open this page from Grok, Claude, Cursor, or Codex when they ask to use your board.” / “Back to the board” | `web/src/Connect.tsx:142–146` |
| Connect page consent | “Let this agent use your board?” / “Allow” / “Deny” | `web/src/Connect.tsx:160`, `web/src/Connect.tsx:190`, `web/src/Connect.tsx:193` |
| Connect page return-address explanation | “The agent name is whatever that client typed at registration. Check the return address before you allow. You can revoke it later from the board, or it ends when you delete your account.” | `web/src/Connect.tsx:182–184` |
| Connect page browser continuity | “Finish sign-in in the browser that opened, then tap Allow.” | `web/src/Connect.tsx:18` |
| Consent permission labels, composed dynamically | “read your board” / “add reminders” / “mark them complete” / “reopen them” | `web/src/consentSummary.ts:52–55` |
| Web privacy: cross-platform function | “Store, sync, and display reminders on the web board, iOS app, widget, and Live Activity.” | `web/src/LegalPages.tsx:144` |
| Web privacy: agent function | “Let an agent you authorized read, add, and complete reminders on your board.” | `web/src/LegalPages.tsx:149` |
| Web privacy: agent permission, excerpt | “If you Allow an MCP client, that client can read and change reminder text on your board until you revoke access.” | `web/src/LegalPages.tsx:201–202` |
| Web privacy: export | “Download a JSON copy of your account, reminders, lock-screen preference, and agent-key names from the signed-in web board (Download my data).” | `web/src/LegalPages.tsx:286–287` |
| Web pricing | “Notepad is free on the App Store and on the web. There are no in-app purchases or subscriptions.” | `web/src/LegalPages.tsx:318–319` |
| Web terms: connection method and revocation, excerpt | “You may connect a client (for example Grok, Claude, Cursor, or Codex) through OAuth or a personal key. Allowing a client lets it read, add, and complete reminders until you revoke that client or a personal key on the web board, or delete your account.” | `web/src/LegalPages.tsx:395–397` |
| Web support: revocation instructions | “Personal keys: signed-in web board → Advanced under Agent access → Revoke. OAuth clients (Grok, Claude, Cursor, Codex): disconnect or sign out in that client, or delete your account for a full wipe. The iOS app has no agent UI.” | `web/src/LegalPages.tsx:514–516` |
| Web support: price | “The app and web board are free. There are no in-app purchases.” | `web/src/LegalPages.tsx:524` |
| iOS sign-in: cross-platform explanation | “Your board on this iPhone, the web, and the Lock Screen.” | `ios/App/SignInView.swift:31` |
| iOS sign-in: shared account | “Use the same address as the web board.” | `ios/App/SignInView.swift:184` |
| iOS Account: existing web destination | “Download My Data” | `ios/App/AccountView.swift:82`; destination resolves to the web root in `ios/App/LMRChrome.swift:4–8` |
| iOS Account: agent mention in deletion footer | “Deletes reminders, device registrations, lock-screen prefs, agent access, and this sign-in.” | `ios/App/AccountView.swift:107` |
| iOS Account: agent mention in deletion confirmation | “This permanently deletes your reminders, device registrations, lock-screen prefs, agent access, and sign-in. This can’t be undone.” | `ios/App/AccountView.swift:161` |
| README: web description, excerpt | “A Supabase-backed reminder board with a React/Vite web app and an iOS 17 app plus WidgetKit extension.” | `README.md:3` |
| README: web routines, excerpt | “Create routines on the web board under **Routine reminders**.” | `README.md:142` |
| README: web-only editing, excerpt | “iOS receives and completes the generated board reminders; routine editing is currently on the web.” | `README.md:146` |
| README: MCP destination | “Remote agents talk to the board at `https://np-mcp.sillyapps.co/mcp`. `https://lmr-mcp.edmundlim.systems/mcp` stays live.” | `README.md:152` |
| README: connector instruction | “Add a custom connector and use OAuth:” / “Settings → Plugins → custom connector” / “Sign in with Google or Apple in the browser that opens, then tap **Allow**.” | `README.md:156`, `README.md:158`, `README.md:160` |
| README: personal keys | “Personal agent keys remain available under **Agent access → Advanced** for hosts that cannot use OAuth. Plugin installs can set `LMR_AGENT_TOKEN`.” | `README.md:162` |
| README: browser authorization | “OAuth is the usual path for clients that complete `/connect`: the client opens a browser, you sign in on the familiar board, tap Allow. No bearer tokens to paste. Personal keys remain under **Advanced** for clients that cannot do OAuth.” | `README.md:166` |

The inventory covers product discovery, setup, consent, management, and relevant supporting documentation. Error strings, generated configuration examples, and repeated legal data-processing mentions are not proposed as nudges. No dedicated native agent-setup copy was found. The native deletion text is inventory only and is unsuitable for promotion. The support revocation paragraph omits the existing Connected agents controls; retain it for Edmund's review rather than reusing it as setup guidance. README deployment-domain descriptions at `README.md:9` and `README.md:249` are historical and should not supply the proposed web destination.

## Proposed placements and triggers

Placement names and behavior below are internal specifications, not UI strings. N = 3 successful reminder additions is a proposed starting threshold, not an existing counter or measured optimum.

| ID | Where | Trigger and destination / behavior | Existing Edmund text to reuse verbatim, or missing copy |
| --- | --- | --- | --- |
| L1 | notepads.dev header and hero | Every landing visit. Retain both existing links to `https://app.notepads.dev` alongside the App Store badge. | “Open app” — `landing/index.html:40`, `landing/index.html:47`. No extra text needed. |
| L2 | notepads.dev, below the platform tags | Static web explanation and link to `https://app.notepads.dev`. | Heading: “Your board, everywhere” — `web/src/App.tsx:134`. Action: “Open app” — `landing/index.html:40`. Supporting explanation: **[PLACEHOLDER - Edmund to write]**. |
| L3 | notepads.dev, after the web explanation | Static agent discovery; lead to Agent access on the signed-in web board, preserving the destination through sign-in. | Heading/action: “Agent access” — `web/src/Board.tsx:726`. Explanation: “Let an agent you authorized read, add, and complete reminders on your board.” — `web/src/LegalPages.tsx:149`. |
| I1 | iOS Account, near the existing web/data links | Available whenever Account opens; web entry opens `https://app.notepads.dev`. Keep the data-export action separate. | Action: “Open app” — `landing/index.html:40`. Explanation: “Your board on this iPhone, the web, and the Lock Screen.” — `ios/App/SignInView.swift:31`. |
| I2 | iOS Account, beside the proposed web entry | Persistent agent-setup entry to the web board's Agent access section. Native connection management is not required for this proposal. | Action: “Agent access” — `web/src/Board.tsx:726`. Explanation of the browser handoff: **[PLACEHOLDER - Edmund to write]**. |
| I3 | iOS empty board, below the existing setup tip | Only after a successful empty-board load, with no error. Do not compete with the first Lock Screen tip; show on a later visit after that tip is dismissed. Once per installation, dismissible. Open the web root. | “Your board on this iPhone, the web, and the Lock Screen.” — `ios/App/SignInView.swift:31`; “Open app” — `landing/index.html:40`; dismissal accessibility label “Dismiss tip” — `ios/App/BoardSetupTip.swift:50`. |
| I4 | iOS board, below the list | After N = 3 confirmed reminder additions, on the next idle visit with the keyboard closed; once per installation and dismissible. Open web Agent access. Do not infer additions from current board size. | Action: “Agent access” — `web/src/Board.tsx:726`; dismissal accessibility label “Dismiss tip” — `ios/App/BoardSetupTip.swift:50`. Milestone explanation: **[PLACEHOLDER - Edmund to write]**. |
| W1 | Web board, near the board heading | Signed-in visits; a compact in-page shortcut scrolls to the existing Agent access section, without starting consent. | “Agent access” — `web/src/Board.tsx:726`. No extra text needed. |
| W2 | Web board empty state | Successful empty-board load and confirmed zero connected agents; hide while either request is loading or failed. Link to the existing Agent access section; keep the reminder composer available. | “Let an agent you authorized read, add, and complete reminders on your board.” — `web/src/LegalPages.tsx:149`; “Agent access” — `web/src/Board.tsx:726`. |
| W3 | Web Agent access, below connection status | Confirmed zero connected agents. Make existing setup guidance prominent; after authorization, keep the existing connected-agent list and revocation controls. | “No connected agents.” — `web/src/ConnectedAgents.tsx:75`; reuse the complete existing setup paragraph at `web/src/Board.tsx:730–731`, retaining its dynamic MCP URL and quoted wording from the inventory. After connection: “These finished Allow. Revoke ends that agent’s access to your board.” — `web/src/ConnectedAgents.tsx:71`. |

## Implementation considerations for a later change

- Begin with L1 and the persistent Account / board entries. Evaluate optional empty-state and milestone nudges separately. This change implements only the requested App Store landing update.
- Keep all proposed surfaces neutral in light and dark themes; no red or orange. Preserve keyboard focus, VoiceOver labels, and comfortable touch targets. Use the existing icon-only dismissal with its existing accessibility label where specified.
- Reuse the current MCP URL/configuration source. Direct visitors to instructions before asking them to initiate connection in their agent. Do not fabricate OAuth state or label a generic link as a completed connection.
- Persist dismissal and a separate successful-addition count if I4 is implemented. Avoid showing both empty-state and milestone nudges in one visit. Hide transient nudges during loading, errors, editing, and consent.
- A destination targeting Agent access after sign-in needs implementation and verification; the current section has a heading ID, but this proposal does not assume that navigation and sign-in already preserve a section target.
- Reuse may cross surfaces, but preserve complete strings and their meaning. If a new heading, description, action, or accessibility label becomes necessary, Edmund supplies it before implementation.

Open copy items: L2 supporting explanation, I2 browser-handoff explanation, and I4 milestone explanation. All three are explicitly marked in the placement table. No proposal text has been added to product UI.
