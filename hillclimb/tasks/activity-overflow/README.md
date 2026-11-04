# Task G: activity-overflow

Branch `hillclimb/activity-overflow`, isolated tool-created checkout based on `10fb05e` (the supplied base commit; no local ref named `hillclimb/ui10fb05e`). Tested/captured source `8b634e0`; later commit contains evidence only. Read rubric and both round2 Sol/Astra reports. No score assigned, reviewers or subagents used, push, PR, merge, deployment, live service test, or datastore mutation.

Structured optional hidden-line metadata fixes SOL2-05 through the local factory/controller, APNs board preparation/byte cap, and native surface cap. Ten original lines produce five visible plus five hidden at the payload cap, then three visible plus seven hidden on the four-row Island. Existing strings, branding/icons, native layout, board budgets/cache/sync identities and provider/auth/lifecycle semantics are retained. See compatibility.md for the unavoidable information limit of legacy summarized payloads.

Setup ran `bash scripts/hillclimb/setup.sh` in this worktree, from the example configuration only. It generated the isolated NotepadHillclimb app/group project. Dependencies were resolved initially; subsequent builds disabled automatic resolution/updates. One derived-data directory: `/tmp/activity-overflow-dd`. Five successful simulator build-for-testing invocations were used during implementation, all for the supplied original simulator with CODE_SIGNING_ALLOWED=NO; the last rebuilt the corrected raster test. No additional derived-data or simulator copies.

Final exact-xctestrun test-without-building run: **266 passed, 0 failed, 0 skipped** = existing249 units +5 new units +existing12 UI (Activity UI fixture now exercises the real multiline pipeline). Includes Activity surface ink across light/dark and default/XXXL/accessibility5, payload/JSON/conservation cases, actual native footer geometry, unchanged 44pt/safe-area/bottom-ink checks. Exact argv, complete structured test tree, summary, and runtime warnings are retained. Per-test timeouts were enabled. Result bundle: `/tmp/activity-overflow-passing.xcresult`. Initial and second failed/cancelled runs are retained separately; they are not claimed as passing. The raster assertion was corrected to inspect ink within every allocated row because digit5 has disconnected bands; no production geometry/assertions were removed.

**4 dependency-free Deno tests passed, 0 failed**, importing actual helpers and mocking board reads, with no network/service permissions. `deno check` passed for both changed helpers. Existing live_activity_test, board_loader_test and device_delivery_test could not execute: cached-only resolution fails because `std@0.224.0/assert/mod.ts` is absent. No replacement assertion library or network download was used. The two associated existing suites were extended but remain unverified here. Parent must rerun these existing suites with the dependency cache available before accepting the backend candidate. This is a validation gap, not a pass.

Eight native PNGs and four source recordings cover expanded Island and Notification Center banners in light/dark at default/XXXL on original `78F5A64F-7B2E-4562-8EF9-10F3312CC694`, host local, iPhone17 Pro simulator, actual iOS26.2. All images individually inspected. Each capture uses real ActivityKit with pushType:nil and one synthetic multiline Reminder through the production pure factory. Four pipeline JSON records show5 visible +5 hidden before rendering. Observed Island totals are3+7/default and2+8/XXXL; banner totals5+5/default and4+6/XXXL. Footers are readable and clear the rounded bottom edges. XXXL visible reminder text uses the existing intentional one-line ellipsis. Build/installed binary hashes match for app and extension. Source hashes, image hashes, pinned commands, navigation output, gesture telemetry and fixture records accompany the captures.

Limits: Notification Center is not a true locked-device state; simulator evidence does not certify physical sensor geometry, arbitrary wallpaper contrast, physical haptics or VoiceOver. Simulator still screenshots omit Island overlays, so expanded PNGs are unmodified frames extracted from the pinned device recording at2s. Snapshot tooling reported `Simulator AX snapshot unavailable (target-resolution-failed); used XCTest for an unverified app generation`, and some transition snapshots warned the surface was still changing. Successful command output and actual settled pixels are retained; snapshots alone are not treated as geometric proof. Existing sign-in Invalid frame dimension warning reproduced once in the full suite. Initial build also reported existing AuthManager/AuthSessionGateTests/AppIntents warnings; no warning-free claim. No assertions or diagnostics were suppressed.

Cleanup: ended only demo-owned Activity IDs, verified owned-ID list empty, restored system light/large, closed this app/session and Device panel without shutdown. Assigned original simulator remains running.

Changed source/test files (all assigned scope):

- `ios/App/HillclimbActivityDemo.swift`
- `ios/Shared/LockScreenLineBudget.swift`
- `ios/Shared/ReminderAttributes.swift`
- `ios/Shared/ReminderLiveActivityController.swift`
- `ios/Tests/ActivityLayoutTests.swift`
- `ios/Tests/ReminderPresentationTests.swift`
- `ios/UITests/ActivityNativeLayoutTests.swift`
- `ios/Widget/ReminderLiveActivity.swift`
- `supabase/functions/_shared/board_loader.ts`
- `supabase/functions/_shared/board_loader_test.ts`
- `supabase/functions/_shared/live_activity.ts`
- `supabase/functions/_shared/live_activity_test.ts`
- `supabase/functions/send-reminder-push/index.ts`

Written by gpt-6.1-sol in Codex on behalf of Edmund
