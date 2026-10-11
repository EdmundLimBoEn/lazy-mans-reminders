# Live Activity recovery investigation

Written by gpt-6.1-sol in T3 Code on behalf of Edmund.

## Provenance and observed failure

The assigned worktree and dirty parent checkout started at `c131c41`. The worktree was fast-forwarded to shipped `c65ef2a31be0fa403c1dfb53c544777e1a2f0e0c` before implementation. [TestFlight run 38131374027](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/38131374027) uploaded version 1.0, build 9. The production `send-reminder-push` version 13 was downloaded into a separate temporary directory. Its five source files matched this shipped baseline.

The parent changes and relevant untracked session helper were inspected without modifying the parent. Only the pending ActivityKit/APNs byte budget and JWT retry changes were adapted. The byte budget includes the empty fixed attributes locally. The retry helper retains the existing `invalid` result on token pruning, which the parent's helper incorrectly collapsed into `failed`. Other pending release fixes were not imported.

## Causes established in code

- `ReminderListView` refreshed once when its view appeared. `ContentView` retried push registration on a warm foreground transition but did not publish or fetch the board. An activity that expired overnight therefore remained absent when reopening an already-running app.
- A failed cold-launch fetch loaded the saved board into the list without publishing it to ActivityKit. Offline reopening could show reminders in the app while leaving the activity absent.
- Activity token observation relied on asynchronous token-change streams without reading available `pushToken` and `pushToStartToken` snapshots. Foreground reconciliation also did not recover token selection after its selected activity disappeared. Snapshot recovery needs acknowledgement tracking, because re-uploading the old token can undo the server's replacement handoff.
- Six valid 500-code-point Unicode reminders exceeded the 4 KB local content and APNs payload limits. The payload regression failed before the fix. The existing expired-JWT retry invalidated the JWT cache while reusing the old authorization header; its regression fails when that header reuse is restored.

These explain reproducible recovery/delivery failures. They do not establish the exact reason iOS removed the reported activity. No physical-device ActivityKit logs were available.

## Production read-only evidence

On October 11, the `live-activity-refresh` cron was active at `*/15 * * * *`, calling `public.request_reminder_push`. That function reads the webhook secret from Vault and targets `send-reminder-push`. The reminder trigger handles insert, update and delete. The handoff migration `202609260001` is applied. Recent stored scheduler responses were HTTP 200, including responses with `sent: 0`.

Two development registrations had no current activity update token. One had a push-to-start token and a retiring token, with the latest start recorded at 16:15 UTC. This is evidence of an unacknowledged renewal, not proof of display. The single production registration had no Live Activity tokens and no recorded start. No tokens, identities, credentials or reminder text were printed. No production test data was created or deleted.

## Fix and validation

Every active scene transition now invokes foreground board reconciliation. The publication coordinator restores a non-empty current cache before fetching, and publishes a successfully fetched board even when empty. A failed read with an empty cache sends no end command. Publication stays behind the existing cleanup gate and reloads the current account's cache.

The controller reads available token snapshots when observing activities and during foreground updates. The registrar remembers an acknowledged activity token across relaunch and omits repeated uploads while accepting a replacement or retrying an unacknowledged token. The server still renews at seven hours and retains the old activity until a different update token arrives. No end-state observer or timer restarts dismissed activities.

Local validation: 69 shared Deno tests passed; `send-reminder-push` type checking passed. Coverage includes Unicode start/update/end payloads, expired JWT retries, invalid-token replacement through the transport, original eight-hour deadlines, failed reads and handoff races. Swift regressions cover warm/offline restoration, confirmed clear, empty-cache failures, account cleanup, cancellation and token snapshot acknowledgement. Hosted native validation and delivery results are recorded after CI below.

## Physical-device acceptance still required

Install the new signed build, open it while signed in, and check foreground recovery without pull-to-refresh. Repeat offline with a saved non-empty board. Leave a reminder through the seven-to-nine-hour renewal window and overnight, then reopen. Confirm a replacement token reaches the server, only one current board remains after retirement, and remote completion of the last reminder clears it. Check explicit dismissal, sign-out and switching between disposable test accounts. The release review account is excluded from testing.

[Apple's ActivityKit constraints](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) cap each activity at eight active hours. [Apple's push lifecycle](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications) permits replacement and background token handling subject to delivery. [Apple's background execution guidance](https://developer.apple.com/forums/thread/685525) rules out guaranteed background refresh intervals. APNs acceptance and CI success cannot close these device gates.
